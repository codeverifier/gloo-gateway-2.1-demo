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
        helm --kube-context ${CLUSTER_CONTEXT} install apps $DIR/sock-shop-microservices-demo/ \
            -n apps
    ;;
    toolbox-sec*)
        echo "------------------------------------------------------------"
        echo "Deploying toolbox in secure mode"
        echo "------------------------------------------------------------"
        echo ""

        kubectl --context ${CLUSTER_CONTEXT} create ns toolbox-sec
        kubectl --context ${CLUSTER_CONTEXT} label namespace toolbox-sec istio.io/rev=$REVISION
        kubectl --context ${CLUSTER_CONTEXT} -n toolbox-sec apply -f $DIR/toolbox/deployment.yaml
    ;;
    toolbox*)
        echo "------------------------------------------------------------"
        echo "Deploying toolbox"
        echo "------------------------------------------------------------"
        echo ""

        kubectl --context ${CLUSTER_CONTEXT} create ns toolbox
        kubectl --context ${CLUSTER_CONTEXT} -n toolbox apply -f $DIR/toolbox/deployment.yaml
    ;;
    websocket*)
        echo "------------------------------------------------------------"
        echo "Deploying websocket demo application"
        echo "------------------------------------------------------------"
        echo ""

        kubectl --context ${CLUSTER_CONTEXT} create ns websocket
        kubectl --context ${CLUSTER_CONTEXT} label namespace websocket istio.io/rev=$REVISION
        kubectl --context ${CLUSTER_CONTEXT} -n websocket apply -f $DIR/websockets/deployment.yaml
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
    toolbox-sec*)
        kubectl --context ${CLUSTER_CONTEXT} -n toolbox-sec delete -f $DIR/toolbox/deployment.yaml
    ;;
    toolbox*)
        kubectl --context ${CLUSTER_CONTEXT} -n toolbox delete -f $DIR/toolbox/deployment.yaml
    ;;
    websocket*)
        kubectl --context ${CLUSTER_CONTEXT} -n websocket delete -f $DIR/websockets/deployment.yaml
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