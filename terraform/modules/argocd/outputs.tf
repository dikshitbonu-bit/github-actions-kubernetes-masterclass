output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}
