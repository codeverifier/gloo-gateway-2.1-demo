#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

provision() {
    case $1 in
    sockshop*)
        echo "------------------------------------------------------------"
        echo "Deploying Sock Shop demo application"
        echo "------------------------------------------------------------"
        echo ""

        kubectl --context ${CLUSTER_CONTEXT} create ns apps
        kubectl --context ${CLUSTER_CONTEXT} label namespace apps istio.io/rev=$REVISION
        helm --kube-context ${CLUSTER_CONTEXT} install apps $DIR/apps/sock-shop-microservices-demo/ \
            -n apps
    ;;
    websocket*)
        echo "------------------------------------------------------------"
        echo "Deploying websocket demo application"
        echo "------------------------------------------------------------"
        echo ""

        kubectl --context ${CLUSTER_CONTEXT} create ns apps
        kubectl --context ${CLUSTER_CONTEXT} label namespace apps istio.io/rev=$REVISION
        kubectl --context ${CLUSTER_CONTEXT} apply -f $DIR/apps/websockets/deployment.yaml
    ;;
    *) echo "Unknown application" >&2; return 1
    ;;
    esac
}

delete() {
    case $1 in
    sockshop*)
        echo "Cleaning up Sock Shop demo application ..."

        helm --kube-context ${CLUSTER_CONTEXT} del apps -n apps
    ;;
    websocket*)
        kubectl --context ${CLUSTER_CONTEXT} delete -f $DIR/apps/websockets/deployment.yaml
    ;;
    *) echo "Unknown application" >&2; return 1
    ;;
    esac
}

shift $((OPTIND-1))
subcommand=$1; shift
case "$subcommand" in
    prov )
        provision "$@"
    ;;
    del )
        delete "$@"
    ;;
    * ) # Invalid subcommand
        if [ ! -z $subcommand ]; then
            echo "Invalid subcommand: $subcommand"
        fi
        exit 1
    ;;
esac