#!/bin/bash

###################################################################
# Script Name   : install.sh
# Description   : Provision a Gloo Gateway environment
# Author        : Kasun Talwatta
# Email         : kasun.talwatta@solo.io
###################################################################

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

error_exit() {
    echo "Error: $1"
    exit 1
}

print_info() {
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo ""
}

debug() {
    echo ""
    echo "$1"
    echo ""
}

wait_for_lb_address() {
    local context=$1
    local service=$2
    local ns=$3
    ip=""
    while [ -z $ip ]; do
        echo "Waiting for $service external IP ..."
        ip=$(kubectl --context ${context} -n $ns get service/$service --output=jsonpath='{.status.loadBalancer}' | grep "ingress")
        [ -z "$ip" ] && sleep 5
    done
    echo "Found $service external IP: ${ip}"
}

prechecks() {
    if [[ -z "${CLUSTER_CONTEXT}" ]]; then
        error_exit "Kubernetes contexts not set. Please set environment variables, \$CLUSTER_CONTEXT."
    fi

    if [[ -z "${CLOUD_PROVIDER}" ]]; then
        error_exit "Cloud provider not set. Please set environment variable, \$CLOUD_PROVIDER."
    fi

    if [[ -z "${CLUSTER_NAME}" ]]; then
        error_exit "Cluster name is not set. Please set environment variable, \$CLUSTER_NAME."
    fi

    if [[ -z "${GLOO_GW_VERSION}" || -z "${GLOO_GW_HELM_VERSION}" ]]; then
        error_exit "Gloo Gateway version is not set. Please set environment variable, \$GLOO_GW_VERSION."
    fi

    if [[ -z "${ISTIO_VERSION}" || -z "${ISTIO_HELM_VERSION}" || -z "${REVISION}" || -z "${ISTIO_SOLO_VERSION}" || -z "${ISTIO_SOLO_REPO}" ]]; then
        error_exit "Istio version details not set. Please set environment variables, \$ISTIO_VERSION, \$ISTIO_SOLO_REPO, \$REVISION."
    fi

    if [[ -z "${GLOO_PLATFORM_GLOO_GATEWAY_LICENSE_KEY}" ]]; then
        error_exit "Gloo Gateway license key not set. Please set environment variables, \$GLOO_PLATFORM_GLOO_GATEWAY_LICENSE_KEY"
    fi
}

install_istio() {
    print_info "Installing Istio"

    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update

    kubectl --context $CLUSTER_CONTEXT create ns istio-config

    debug "Installing Istio base ...."
    envsubst < <(cat $DIR/core/istio/base-helm-values.yaml) | helm --kube-context ${CLUSTER_CONTEXT} install istio-base istio/base \
        -n istio-system \
        --version $ISTIO_HELM_VERSION \
        --create-namespace -f -

    debug "Installing Istio control plane ...."
    envsubst < <(cat $DIR/core/istio/istiod-helm-values.yaml) | helm --kube-context ${CLUSTER_CONTEXT} install istiod istio/istiod \
        -n istio-system \
        --version $ISTIO_HELM_VERSION \
        --create-namespace -f -
    kubectl --context ${CLUSTER_CONTEXT} \
        -n istio-system wait deploy/istiod-${REVISION} --for condition=Available=True --timeout=90s

    debug "Installing Istio ingress gateways ...."
    envsubst < <(cat $DIR/core/istio/ingress-gateway-helm-values.yaml) | helm --kube-context ${CLUSTER_CONTEXT} install istio-ingressgateway istio/gateway \
        -n istio-ingress \
        --version $ISTIO_HELM_VERSION \
        --create-namespace -f -
    kubectl --context ${CLUSTER_CONTEXT} \
        -n istio-ingress wait deploy/istio-ingressgateway --for condition=Available=True --timeout=90s
}


install_gloo_gateway() {
    print_info "Installing Gloo Gateway"

    helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise 
    helm repo update
    helm pull gloo-mesh-enterprise/gloo-mesh-enterprise --version $GLOO_GW_HELM_VERSION --untar
    kubectl --context ${CLUSTER_CONTEXT} apply -f gloo-mesh-enterprise/charts/gloo-mesh-crds/crds
    rm -rf gloo-mesh-enterprise

    envsubst '${GLOO_PLATFORM_GLOO_GATEWAY_LICENSE_KEY},${CLUSTER_NAME}' < <(cat $DIR/core/gloo-platform/gloo-gateway-2.1.yaml) | helm install gloo-gateway gloo-mesh-enterprise/gloo-mesh-enterprise \
        --kube-context ${CLUSTER_CONTEXT} \
        --namespace gloo-gateway \
        --version ${GLOO_GW_HELM_VERSION} \
        --create-namespace \
        -f -

    kubectl --context ${CLUSTER_CONTEXT} create namespace gloo-gateway-addons
    kubectl --context ${CLUSTER_CONTEXT} label namespace gloo-gateway-addons istio.io/rev=$REVISION

    helm install gloo-gateway-addons gloo-mesh-agent/gloo-mesh-agent \
        --kube-context=${CLUSTER_CONTEXT} \
        --namespace gloo-gateway-addons \
        --set glooMeshAgent.enabled=false \
        --set rate-limiter.enabled=true \
        --set ext-auth-service.enabled=true \
        --version $GLOO_GW_HELM_VERSION
}

# Create a temp dir (for any internally generated files)
mkdir -p $DIR/_output

# Run prechecks to begin with
prechecks

should_deploy_integrations=false

SHORT=i,h
LONG=integrations,help
OPTS=$(getopt -a -n "install.sh" --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while : 
do
  case "$1" in
    -i | --integrations )
      shift 1
      should_deploy_integrations=true
      ;;
    -h | --help)
      help
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      help
      ;;
  esac
done

echo -n "Deploying Gloo Gateway"
echo ""

if [[ "$should_deploy_integrations" == true ]]; then
    $DIR/integrations/provision-integrations.sh -p $CLOUD_PROVIDER -c $CLUSTER_CONTEXT -n $CLUSTER_NAME -s external_dns,cert_manager,keycloak
fi

install_istio

install_gloo_gateway

echo ""
echo "Finished installing Gloo Gateway"