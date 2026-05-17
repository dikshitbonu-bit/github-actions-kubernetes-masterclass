#!/bin/bash
# shellcheck shell=bash
set -e

ENV=${1:-dev}
NAMESPACE="skillpulse-${ENV}"

echo "==> Deploying to ${ENV} (namespace: ${NAMESPACE})..."
kubectl apply -f "argocd/${ENV}/application.yaml"

echo "==> Waiting for pods to be ready in ${NAMESPACE}..."
kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout=300s

echo "==> Applying gateway phase1 (HTTP only)..."
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: skillpulse-gateway
  namespace: ${NAMESPACE}
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

echo "==> Waiting for NLB hostname..."
until kubectl get gateway skillpulse-gateway -n "${NAMESPACE}" \
  -o jsonpath='{.status.addresses[0].value}' 2>/dev/null | grep -q '.'; do
  sleep 5
done

NLB_HOSTNAME=$(kubectl get gateway skillpulse-gateway -n "${NAMESPACE}" \
  -o jsonpath='{.status.addresses[0].value}')
echo "==> NLB hostname: ${NLB_HOSTNAME}"

echo "==> Resolving NLB hostname to IP (may take a few minutes)..."
NLB_IP=""
while [ -z "${NLB_IP}" ]; do
  NLB_IP=$(nslookup "${NLB_HOSTNAME}" | awk '/^Address: / { print $2 }' | head -1)
  [ -z "${NLB_IP}" ] && echo "DNS not ready yet, retrying..." && sleep 10
done

NIP_HOST="${NLB_IP}.nip.io"
echo "==> NIP hostname: ${NIP_HOST}"

echo "==> Applying gateway phase2 (HTTPS listener + HTTPRoute)..."
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: skillpulse-gateway
  namespace: ${NAMESPACE}
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "${NIP_HOST}"
      tls:
        mode: Terminate
        certificateRefs:
          - name: skillpulse-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: skillpulse-route
  namespace: ${NAMESPACE}
spec:
  parentRefs:
    - name: skillpulse-gateway
  hostnames:
    - "${NIP_HOST}"
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF

echo "==> Applying cert-manager ClusterIssuer and Certificate..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: dikshitbonu@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: skillpulse-gateway
                namespace: ${NAMESPACE}
                group: gateway.networking.k8s.io
                kind: Gateway
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: skillpulse-tls
  namespace: ${NAMESPACE}
spec:
  secretName: skillpulse-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "${NIP_HOST}"
EOF

echo "==> Waiting for TLS certificate..."
kubectl wait --for=condition=Ready certificate/skillpulse-tls \
  -n "${NAMESPACE}" --timeout=300s

echo "==> App live at https://${NIP_HOST}"
