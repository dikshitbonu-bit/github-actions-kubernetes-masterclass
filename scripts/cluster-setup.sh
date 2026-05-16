#!/bin/bash
# shellcheck shell=bash
set -e

echo "==> Installing Gateway API CRDs v1.2.1..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

echo "==> Installing Envoy Gateway v1.4.0..."
helm install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version v1.4.0 \
  -n envoy-gateway-system \
  --create-namespace \
  --wait

echo "==> Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true \
  --wait

echo "==> Installing kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set grafana.service.type=LoadBalancer \
  --wait

echo "==> Fetching ArgoCD URL..."
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "=== Add GitHub Webhook ==="
echo "Go to: https://github.com/dikshitbonu-bit/github-actions-kubernetes-masterclass/settings/hooks"
echo "Payload URL: https://${ARGOCD_URL}/api/webhook"
echo "Content-Type: application/json"
echo "Secret: skillpulse-webhook-secret"
echo "Event: push only"
