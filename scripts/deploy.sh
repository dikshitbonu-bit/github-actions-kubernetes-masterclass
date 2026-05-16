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
until [ -n "${NLB_IP}" ]; do
  NLB_IP=$(nslookup "${NLB_HOSTNAME}" 2>/dev/null \
    | awk '/^Address/ { print $2 }' \
    | grep -v '#' \
    | head -1)
  [ -z "${NLB_IP}" ] && sleep 10
done

NIP_HOST="${NLB_IP}.nip.io"
echo "==> NIP hostname: ${NIP_HOST}"

echo "==> Applying gateway phase2 (HTTPS + cert-manager via Helm)..."
helm upgrade skillpulse ./helm/skillpulse \
  -f helm/skillpulse/values.yaml \
  -f "helm/skillpulse/values-${ENV}.yaml" \
  --set gateway.enabled=true \
  --set certmanager.enabled=true \
  --set "gateway.hostname=${NIP_HOST}" \
  -n "${NAMESPACE}"

echo "==> Waiting for TLS certificate..."
kubectl wait --for=condition=Ready certificate/skillpulse-tls \
  -n "${NAMESPACE}" --timeout=300s

echo "==> App live at https://${NIP_HOST}"
