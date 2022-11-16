# Gloo Gateway Demo - v2.1.0

Demo of Gloo Gateway on Gloo Platform version `2.1.0` on a single cluster.

## Prerequisites

1. Install tools

  | Command   | Version |      Installation      |
  |:----------|:---------------|:-------------|
  | `helm` | latest | `brew install helm` |
  | `istioctl` | `1.15.3` | `asdf install istioctl 1.15.3` |
  | `meshctl` | `2.1.0` | `curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v2.1.0 sh -` |
  | Vault | latest | `brew tap hashicorp/tap && brew install hashicorp/tap/vault` |
  | `cfssl` | latest | `brew install cfssl` |
  | `jq` | latest | `brew install jq` |
  | `kustomize` | latest | `brew install kustomize` |
  | `getopt` | latest | `brew install gnu-getopt` |

2. Set up environment variables

  ```
  export PROJECT="demo-gg-2-1"
  export CLUSTER_OWNER="kasunt"
  export GKE_CLUSTER_REGION="australia-southeast1"

  export PARENT_DOMAIN_NAME="${CLUSTER_OWNER}.apac.fe.gl00.net"
  export DOMAIN_NAME="${PROJECT}.${PARENT_DOMAIN_NAME}"

  export CLUSTER_NAME="${PROJECT}-cluster"

  export CLOUD_PROVIDER="gke"

  export CLUSTER_CONTEXT="gke_$(gcloud config get-value project)_${GKE_CLUSTER_REGION}_${CLUSTER_OWNER}-${CLUSTER}"

  export GLOO_GW_VERSION="2.1.0"
  export GLOO_GW_HELM_VERSION="v${GLOO_GW_VERSION}"

  export ISTIO_VERSION="1.15.3"
  export ISTIO_HELM_VERSION="${ISTIO_VERSION}"
  export ISTIO_SOLO_VERSION="${ISTIO_VERSION}-solo"
  export ISTIO_SOLO_REPO="us-docker.pkg.dev/gloo-mesh/istio-1cf99a48c9d8"
  export REVISION="1-15-3"

  export KEYCLOAK_HELM_VERSION="12.1.2" # Version 19.0.3
  export CERT_MANAGER_VERSION="v1.10.0" # Version 1.10.0
  export EXTERNAL_DNS_HELM_VERSION="1.11.0" # Version 0.12.2
  ```

3. Provision the clusters

  ```
  ./cluster-provision/scripts/provision-gke-cluster.sh create -n $CLUSTER_NAME -o $CLUSTER_OWNER -a 1 -r $GKE_CLUSTER_REGION
  ```

## Instructions

Deploy all the services (including integrations)

```
./install.sh -i
```

## Application Demo

### Deployment

```
./apps/apps-deploy.sh prov
```

### Feature Demo

| Feature   |      Command      |  Notes |
|:----------|:-------------|:------|
| Securing Gateway with TLS | `./configuration/sock-shop/secure-gateway.sh prov` | Uses cert manager to generate a LetsEncrypt cert |
| Web firewall policy | `./configuration/sock-shop/web-firewall-policy.sh prov` | Applies modsec rules to only allow certain HTTP methods |
| OIDC authentication | `./configuration/sock-shop/oidc-authentication.sh prov` | Secure the application with OIDC |
| Enforcing authorization | `./configuration/sock-shop/enforce-authorization.sh prov` | Requires a valid JWT and subsequently validates the claim |
