#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

provision() {
    echo "------------------------------------------------------------"
    echo "Enforcing mTLS within apps namespace"
    echo "------------------------------------------------------------"
    echo ""

    envsubst < <(cat $DIR/enforce-mtls/enforce-mtls.yaml) | kubectl apply -f - 2>&1 >/dev/null
    echo "done"
}

delete() {
    echo "Cleaning up ..."

    envsubst < <(cat $DIR/enforce-mtls/enforce-mtls.yaml) | kubectl delete -f - 2>&1 >/dev/null
    echo "done"
}

test() {
    echo "------------------------------------------------------------"
    echo "Testing mTLS"
    echo "------------------------------------------------------------"
    echo ""
    echo "**Case**: toolbox service outside the mesh (unsecured) -> front-end application in the mesh (secured)"
    echo "**Result**:"
    kubectl exec "$(kubectl get pod -l app=toolbox -n toolbox -o jsonpath={.items..metadata.name})" -n toolbox -c toolbox -- curl http://front-end.apps:80 -s -o /dev/null -w "toolbox to front-end.apps: %{http_code}\n"

    sleep 15

    echo ""
    echo "**Case**: toolbox service in the mesh (secured) -> front-end application in the mesh (secured)"
    echo "**Result**:"
    kubectl exec "$(kubectl get pod -l app=toolbox -n toolbox-sec -o jsonpath={.items..metadata.name})" -n toolbox-sec -c toolbox -- curl http://front-end.apps:80 -s -o /dev/null -w "toolbox to front-end.apps: %{http_code}\n"
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
    test )
        test
    ;;
    * ) # Invalid subcommand
        if [ ! -z $subcommand ]; then
            echo "Invalid subcommand: $subcommand"
        fi
        exit 1
    ;;
esac