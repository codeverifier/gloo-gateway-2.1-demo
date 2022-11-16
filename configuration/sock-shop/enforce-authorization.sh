#!/usr/bin/env bash

set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

log() { echo -e "$*" >&2; }
error_exit() { echo "Error: $1"; exit 1; }

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
hs_sign() { openssl dgst -binary -sha"${1}" -hmac "${2}"; }
rs_sign() { openssl dgst -binary -sha"${1}" -sign <(printf '%s\n' "${2}"); }

provision() {
    echo "--------------------------------------------------------------"
    echo "Securing the gateway with a valid JWT & claim based validation"
    echo "--------------------------------------------------------------"
    echo ""

    payload='{
        "iss": "https://localhost",
        "org": "solo.io"
    }'

    gen_rsa256_token "$payload"

    envsubst < <(cat $DIR/enforce-authorization/tls-certificate.yaml) | kubectl apply -f -
    kubectl create secret generic local-jwks-verification -n apps --from-file=public_key=$DIR/../../_output/jwt_gen/public_key.pem
    kubectl create configmap allow-only-solo-org -n apps --from-file=$DIR/enforce-authorization/policy.rego
    envsubst < <(cat $DIR/enforce-authorization/authorization-policy.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/enforce-authorization/ext-auth-server.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/enforce-authorization/validate-claim-policy.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/enforce-authorization/virtual-gateway.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/enforce-authorization/route-table.yaml) | kubectl apply -f -
}

delete() {
    echo "Cleaning up ..."

    kubectl delete secret local-jwks-verification -n apps
    kubectl delete configmap allow-only-solo-org -n apps
    envsubst < <(cat $DIR/enforce-authorization/tls-certificate.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/enforce-authorization/authorization-policy.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/enforce-authorization/ext-auth-server.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/enforce-authorization/validate-claim-policy.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/enforce-authorization/virtual-gateway.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/enforce-authorization/route-table.yaml) | kubectl delete -f -
}

gen_rsa256_token() {
    rm -rf $DIR/../../_output/jwt_gen
    mkdir -p $DIR/../../_output/jwt_gen

    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
        -subj "/C=US/ST=MA/L=Boston/O=Solo.io/OU=DevOps/CN=localhost" \
        -keyout $DIR/../../_output/jwt_gen/private.key \
        -out $DIR/../../_output/jwt_gen/public_cert.pem
     openssl x509 -pubkey -noout -in $DIR/../../_output/jwt_gen/public_cert.pem > $DIR/../../_output/jwt_gen/public_key.pem

    rsa_token=$(cat $DIR/../../_output/jwt_gen/private.key)

    gen_jwt_token rs256 "$rsa_token" "$@"
}

gen_jwt_token() {
    log "Generating a valid JWT token ...."

    local algo=$1
    local jwt_secret=$2
    local payload=$3
    local encode_secret=$4
    local expiration_in_sec=$5

    [ -n "$algo" ] || error_exit "Algorithm not specified, RS256 or HS256."
    [ -n "$jwt_secret" ] || error_exit "Secret not provided."

    algo=${algo^^}

    local default_payload='{
    }'

    # Number of seconds to expire token, default 1h
    local expire_seconds="${expiration_in_sec:-3600}"

    # Check if secret should be base64 encoded
    ${encode_secret:-false} && jwt_secret=$(printf %s "$jwt_secret" | base64 --decode)

    header_template='{
        "typ": "JWT",
        "kid": "0001"
    }'

    gen_header=$(jq -c \
        --arg alg "${algo}" \
        '
        .alg = $alg
        ' <<<"${header_template}" | tr -d '\n') || error_exit "Unable to generate JWT header"

    # Generate payload
    gen_payload=$(jq -c \
        --arg iat_str "$(date +%s)" \
        --arg alg "${algo}" \
        --arg expiry_str "${expiration_in_sec:-7200}" \
        '
        ($iat_str | tonumber) as $iat
        | ($expiry_str | tonumber) as $expiry
        | .alg = $alg
        | .iat = $iat
        | .exp = ($iat + $expiry)
        | .nbf = $iat
        ' <<<"${payload:-$default_payload}" | tr -d '\n') || error_exit "Unable to generate JWT payload"

    signed_content="$(json <<<"$gen_header" | b64enc).$(json <<<"$gen_payload" | b64enc)"

    # Based on algo sign the content
    case ${algo} in
        HS*) signature=$(printf %s "$signed_content" | hs_sign "${algo#HS}" "$jwt_secret" | b64enc) ;;
        RS*) signature=$(printf %s "$signed_content" | rs_sign "${algo#RS}" "$jwt_secret" | b64enc) ;;
        *) echo "Unknown algorithm" >&2; return 1 ;;
    esac

    printf 'Successfully generated JWT token. ** Expires in %s seconds ** ====> %s\n\n' "${expire_seconds}" "${signed_content}.${signature}"
}

shift $((OPTIND-1))
subcommand=$1; shift
case "$subcommand" in
    prov )
        provision
    ;;
    del )
        delete
    ;;
    * ) # Invalid subcommand
        if [ ! -z $subcommand ]; then
            echo "Invalid subcommand: $subcommand"
        fi
        exit 1
    ;;
esac