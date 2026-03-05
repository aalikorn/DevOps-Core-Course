# Lab 6 — Advanced Ansible & CI/CD

## Overview
In this lab, I enhanced the Ansible automation with production-ready features:
- Refactored roles with **blocks** and **tags** for better error handling and selective execution.
- Upgraded the deployment from `docker run` to **Docker Compose** using Jinja2 templates.
- Implemented **role dependencies** to ensure correct execution order.
- Added **wipe logic** with double-gating (variable + tag) for safe resource cleanup.
- Integrated **GitHub Actions** for automated CI/CD.

## Blocks & Tags
I refactored the `common` and `docker` roles to use blocks. 
- **Blocks** group logically related tasks and allow for `rescue` (error handling) and `always` (cleanup/logging) sections.
- **Tags** allow us to run only specific parts of the playbook, e.g., `--tags "docker_install"`.

### Example Execution:
```bash
# Run only package installation
ansible-playbook provision.yml --tags "packages"

# Skip common configuration
ansible-playbook provision.yml --skip-tags "common"
```

## Docker Compose Migration
The `web_app` role now uses Docker Compose instead of standalone Docker containers. This provides better management of container networking and environment variables.

### Template: `docker-compose.yml.j2`
The template dynamically configures the service based on Ansible variables.

## Wipe Logic
A new `wipe.yml` task was added to the `web_app` role. It is "double-gated" for safety:
1. Must pass `-e "web_app_wipe=true"`
2. Must include `--tags "web_app_wipe"`

## CI/CD Integration
The GitHub Actions workflow `.github/workflows/ansible-deploy.yml` was fixed and configured to:
1. **Lint** the Ansible code.
2. **Deploy** by running the playbooks on the target VM.
3. **Verify** the deployment by checking the health status of the application.

### Secrets required on GitHub:
- `VM_HOST`
- `VM_USER`
- `SSH_PRIVATE_KEY`
- `ANSIBLE_VAULT_PASSWORD` (if using Vault)
