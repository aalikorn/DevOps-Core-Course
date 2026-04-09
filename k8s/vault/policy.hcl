# Vault policy for devops-python-app
# This policy grants read access to application secrets

path "secret/data/devops-python-app/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/devops-python-app/*" {
  capabilities = ["read", "list"]
}
