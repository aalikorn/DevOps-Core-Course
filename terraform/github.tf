resource "github_repository" "course_repo" {
  name        = "DevOps-Core-Course"
  description = "🚀Production-grade DevOps course: 18 hands-on labs covering Docker, Kubernetes, Helm, Terraform, Ansible, CI/CD, GitOps (ArgoCD), monitoring (Prometheus/Grafana), and more. Build real-world skills with progressive delivery, secrets management, and cloud-native deployments."
  visibility  = "public"

  has_issues      = false
  has_projects    = true
  has_wiki        = true
  has_downloads   = true
  has_discussions = false

  # Эти параметры соответствуют реальности после импорта
}
