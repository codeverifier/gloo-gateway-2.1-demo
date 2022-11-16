#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

error_exit() {
    echo "Error: $1"
    exit 1
}

provision() {
    echo "------------------------------------------------------------"
    echo "Securing the gateway with TLS & OIDC Authentication"
    echo "------------------------------------------------------------"
    echo ""

    if [[ -f $DIR/../../_output/keycloak_env.sh ]]; then
        source $DIR/../../_output/keycloak_env.sh
    else
        error_exit "Unable to find 'keycloak_env.sh'"
    fi

    if [[ -z $CLIENT_SECRET_BASE64_ENCODED ]]; then
        error_exit "Please provide OIDC secret via environment variable \$CLIENT_SECRET_BASE64_ENCODED"
    fi
    if [[ -z $CLIENT_ID ]]; then
        error_exit "Please provide OIDC client ID via environment variable \$CLIENT_ID"
    fi

    envsubst < <(cat $DIR/oidc-authentication/tls-certificate.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/oidc-authentication/ext-auth-server.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/oidc-authentication/oidc-client-secret.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/oidc-authentication/oidc-auth-policy.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/oidc-authentication/virtual-gateway.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/oidc-authentication/route-table.yaml) | kubectl apply -f -
}

delete() {
    echo "Cleaning up ..."

    envsubst < <(cat $DIR/oidc-authentication/tls-certificate.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/oidc-authentication/ext-auth-server.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/oidc-authentication/oidc-client-secret.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/oidc-authentication/oidc-auth-policy.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/oidc-authentication/virtual-gateway.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/oidc-authentication/route-table.yaml) | kubectl delete -f -
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