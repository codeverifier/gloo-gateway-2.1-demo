#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

provision() {
    echo "------------------------------------------------------------"
    echo "Protecting applications with WAF"
    echo "------------------------------------------------------------"
    echo ""

    envsubst < <(cat $DIR/web-firewall-policy/tls-certificate.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/web-firewall-policy/virtual-gateway.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/web-firewall-policy/route-table.yaml) | kubectl apply -f -
    envsubst < <(cat $DIR/web-firewall-policy/waf-policy.yaml) | kubectl apply -f -
}

delete() {
    echo "Cleaning up ..."

    envsubst < <(cat $DIR/web-firewall-policy/tls-certificate.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/web-firewall-policy/virtual-gateway.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/web-firewall-policy/route-table.yaml) | kubectl delete -f -
    envsubst < <(cat $DIR/web-firewall-policy/waf-policy.yaml) | kubectl delete -f -
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