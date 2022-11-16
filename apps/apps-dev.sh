#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

provision() {
    echo "------------------------------------------------------------"
    echo "Deploying Sock Shop demo application"
    echo "------------------------------------------------------------"
    echo ""

    kubectl --context ${CLUSTER_CONTEXT} create ns apps
    kubectl --context ${CLUSTER_CONTEXT} label namespace apps istio.io/rev=$REVISION
    helm --kube-context ${CLUSTER_CONTEXT} install apps $DIR/apps/sock-shop-microservices-demo/ \
        -n apps
}

delete() {
    echo "Cleaning up ..."

    helm --kube-context ${CLUSTER_CONTEXT} del apps -n apps
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