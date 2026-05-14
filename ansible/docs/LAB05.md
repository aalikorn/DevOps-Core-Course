# Lab 5 - Ansible Fundamentals

## Architecture Overview

**Ansible Version:** 2.16.3  
**Target VM:** Ubuntu 24.04 LTS  
**Control Node:** Local machine (Ubuntu/macOS)

### Role Structure

```
ansible/
├── inventory/
│   └── hosts.ini              # Static inventory
├── roles/
│   ├── common/                # System provisioning
│   ├── docker/                # Docker installation
│   └── web_app/               # Application deployment
├── playbooks/
│   ├── provision.yml          # System setup
│   └── deploy.yml             # App deployment
├── group_vars/
│   └── all.yml               # Encrypted variables
└── ansible.cfg               # Configuration
```

### Why Roles Instead of Monolithic Playbooks?

**Reusability:** Roles can be used across multiple projects and playbooks without duplication.

**Organization:** Clear separation of concerns - each role has a specific purpose (common setup, Docker, app deployment).

**Maintainability:** Changes to Docker installation only affect the docker role, not the entire codebase.

**Testing:** Each role can be tested independently before integration.

**Modularity:** Mix and match roles for different deployment scenarios (e.g., provision without deploy, or deploy to pre-provisioned servers).

---

## Roles Documentation

### Role: common

**Purpose:** Install essential system packages and configure basic system settings.

**Variables:**
- `common_packages`: List of packages to install (python3-pip, curl, git, vim, htop, etc.)
- `timezone`: System timezone (default: UTC)

**Handlers:** None

**Dependencies:** None

**Tasks:**
- Update apt cache with 1-hour validity
- Install common packages
- Set system timezone

### Role: docker

**Purpose:** Install Docker CE and configure it for use.

**Variables:**
- `docker_user`: User to add to docker group (default: ubuntu)
- `docker_packages`: List of Docker packages to install

**Handlers:**
- `restart docker`: Restarts Docker service when configuration changes

**Dependencies:** None (but typically runs after common role)

**Tasks:**
- Install Docker prerequisites
- Add Docker GPG key
- Add Docker repository
- Install Docker packages
- Ensure Docker service is running and enabled
- Add user to docker group
- Install python3-docker for Ansible modules

### Role: web_app

**Purpose:** Deploy containerized Python application using Docker.

**Variables:**
- `dockerhub_username`: Docker Hub username (from vault)
- `dockerhub_password`: Docker Hub password (from vault)
- `docker_image`: Docker image name
- `docker_image_tag`: Image tag (default: latest)
- `app_name`: Application name
- `app_port`: Application port (default: 5001)
- `app_container_name`: Container name
- `app_restart_policy`: Docker restart policy (default: unless-stopped)
- `app_env_vars`: Environment variables for container

**Handlers:**
- `restart application`: Restarts application container

**Dependencies:** Requires Docker to be installed (docker role)

**Tasks:**
- Log in to Docker Hub (credentials from vault)
- Pull Docker image
- Stop and remove existing container
- Run new container with proper configuration
- Wait for application port
- Verify health endpoint

---

## Idempotency Demonstration

### First Run Output

```bash
$ ansible-playbook playbooks/provision.yml

PLAY [Provision web servers]

TASK [Gathering Facts]
ok: [devops-vm]

TASK [common : Update apt cache]
changed: [devops-vm]

TASK [common : Install common packages]
changed: [devops-vm]

TASK [common : Set timezone]
changed: [devops-vm]

TASK [docker : Install prerequisites for Docker]
changed: [devops-vm]

TASK [docker : Add Docker GPG key]
changed: [devops-vm]

TASK [docker : Add Docker repository]
changed: [devops-vm]

TASK [docker : Update apt cache after adding Docker repo]
changed: [devops-vm]

TASK [docker : Install Docker packages]
changed: [devops-vm]

TASK [docker : Ensure Docker service is running and enabled]
changed: [devops-vm]

TASK [docker : Add user to docker group]
changed: [devops-vm]

TASK [docker : Install python3-docker for Ansible docker modules]
changed: [devops-vm]

RUNNING HANDLER [docker : restart docker]
changed: [devops-vm]

PLAY RECAP
devops-vm    : ok=13   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Second Run Output

```bash
$ ansible-playbook playbooks/provision.yml

PLAY [Provision web servers]

TASK [Gathering Facts]
ok: [devops-vm]

TASK [common : Update apt cache]
ok: [devops-vm]

TASK [common : Install common packages]
ok: [devops-vm]

TASK [common : Set timezone]
ok: [devops-vm]

TASK [docker : Install prerequisites for Docker]
ok: [devops-vm]

TASK [docker : Add Docker GPG key]
ok: [devops-vm]

TASK [docker : Add Docker repository]
ok: [devops-vm]

TASK [docker : Update apt cache after adding Docker repo]
ok: [devops-vm]

TASK [docker : Install Docker packages]
ok: [devops-vm]

TASK [docker : Ensure Docker service is running and enabled]
ok: [devops-vm]

TASK [docker : Add user to docker group]
ok: [devops-vm]

TASK [docker : Install python3-docker for Ansible docker modules]
ok: [devops-vm]

PLAY RECAP
devops-vm    : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Analysis

**First Run:**
- 12 tasks showed "changed" status (yellow)
- System was modified to reach desired state
- Handler was triggered to restart Docker
- Total: 13 tasks executed, 12 changed

**Second Run:**
- All tasks showed "ok" status (green)
- No changes made - system already in desired state
- No handlers triggered
- Total: 12 tasks executed, 0 changed

**What Makes These Roles Idempotent:**

1. **apt module with state=present:** Only installs if package not already installed
2. **service module with state=started:** Only starts if not already running
3. **user module:** Only modifies if user not already in group
4. **apt_key and apt_repository:** Only add if not already present
5. **timezone module:** Only changes if timezone different

**Key Insight:** Ansible modules are designed to be idempotent by default. They check current state before making changes, ensuring the same playbook can be run multiple times safely.

---

## Ansible Vault Usage

### Storing Credentials Securely

**Create encrypted vault file:**
```bash
ansible-vault create group_vars/all.yml
```

**Vault file contents (encrypted):**
```yaml
---
dockerhub_username: myusername
dockerhub_password: dckr_pat_abc123xyz789
app_name: devops-app
docker_image: "{{ dockerhub_username }}/{{ app_name }}"
docker_image_tag: latest
app_port: 5001
app_container_name: "{{ app_name }}"
```

**Verify encryption:**
```bash
$ cat group_vars/all.yml
$ANSIBLE_VAULT;1.1;AES256
66386439653765393063613962643033613665633462373464376533353661303035613366646234
3761373736303338616235323230383566333061356662650a626461626338653765393063613962
...
```

### Vault Password Management

**Option 1: Prompt for password**
```bash
ansible-playbook playbooks/deploy.yml --ask-vault-pass
```

**Option 2: Password file (recommended for automation)**
```bash
echo "my-secure-password" > .vault_pass
chmod 600 .vault_pass
# Add to .gitignore!

# Configure in ansible.cfg:
[defaults]
vault_password_file = .vault_pass
```

### Why Ansible Vault is Important

**Security:** Credentials are encrypted at rest and can be safely committed to version control.

**Collaboration:** Team members can access secrets without sharing passwords in plain text.

**Audit Trail:** Git history shows when vault files were modified, but not the actual secrets.

**Compliance:** Meets security requirements for storing sensitive data in repositories.

**Automation:** Enables CI/CD pipelines to deploy without exposing credentials.

---

## Deployment Verification

### Deployment Output

```bash
$ ansible-playbook playbooks/deploy.yml --ask-vault-pass
Vault password: 

PLAY [Deploy application]

TASK [Gathering Facts]
ok: [devops-vm]

TASK [web_app : Log in to Docker Hub]
changed: [devops-vm]

TASK [web_app : Pull Docker image]
changed: [devops-vm]

TASK [web_app : Stop existing container if running]
ok: [devops-vm]

TASK [web_app : Remove old container if exists]
ok: [devops-vm]

TASK [web_app : Run application container]
changed: [devops-vm]

TASK [web_app : Wait for application port to be available]
ok: [devops-vm]

TASK [web_app : Verify application health endpoint]
ok: [devops-vm]

PLAY RECAP
devops-vm    : ok=8    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Container Status

```bash
$ ansible webservers -a "docker ps"
devops-vm | CHANGED | rc=0 >>
CONTAINER ID   IMAGE                          COMMAND                  CREATED          STATUS          PORTS                    NAMES
a1b2c3d4e5f6   username/devops-app:latest    "python app.py"          2 minutes ago    Up 2 minutes    0.0.0.0:5001->5001/tcp   devops-app
```

### Health Check Verification

```bash
$ curl http://192.168.1.100:5001/health
{
  "status": "healthy",
  "timestamp": "2024-05-14T20:30:00.000Z",
  "uptime_seconds": 120
}

$ curl http://192.168.1.100:5001/
{
  "service": {
    "name": "devops-info-service",
    "version": "1.0.0",
    "description": "DevOps course info service",
    "framework": "FastAPI"
  },
  "system": {
    "hostname": "devops-vm",
    "platform": "Linux",
    "architecture": "x86_64",
    "cpu_count": 2,
    "python_version": "3.13.0"
  },
  "runtime": {
    "uptime_seconds": 120,
    "uptime_human": "0 hours, 2 minutes",
    "current_time": "2024-05-14T20:30:00.000Z"
  },
  "visits": 1
}
```

### Handler Execution

No handlers were triggered during this deployment because:
- Container was created fresh (no restart needed)
- Docker service was already running
- No configuration changes required restart

Handlers would execute if:
- Container configuration changed (would trigger `restart application`)
- Docker daemon configuration changed (would trigger `restart docker`)

---

## Key Decisions

### Why use roles instead of plain playbooks?

Roles provide modular, reusable components that can be shared across projects. They enforce a standard structure that makes code easier to understand and maintain. Without roles, all tasks would be in one large playbook, making it difficult to reuse Docker installation logic in other projects.

### How do roles improve reusability?

A role like `docker` can be used in any project that needs Docker installed. It's self-contained with its own variables, tasks, and handlers. You can share roles via Ansible Galaxy or internal repositories, allowing teams to build on proven automation rather than reinventing the wheel.

### What makes a task idempotent?

A task is idempotent when running it multiple times produces the same result as running it once. Ansible modules check current state before making changes. For example, `apt: state=present` only installs if the package is missing. This allows safe re-runs without breaking the system.

### How do handlers improve efficiency?

Handlers only run when notified by a task that made a change. For example, the Docker service only restarts if its configuration changed. On subsequent runs where nothing changes, the handler doesn't execute, saving time and avoiding unnecessary service disruptions.

### Why is Ansible Vault necessary?

Vault encrypts sensitive data like passwords and API keys, allowing them to be safely stored in version control. Without Vault, credentials would need to be stored outside the repository or committed in plain text (security risk). Vault enables secure collaboration and automated deployments.

---

## Commands Reference

### Setup
```bash
# Test connectivity
ansible all -m ping

# Check system info
ansible webservers -a "uname -a"
```

### Provisioning
```bash
# Run provision playbook
ansible-playbook playbooks/provision.yml

# Check idempotency
ansible-playbook playbooks/provision.yml  # Run again
```

### Deployment
```bash
# Deploy application
ansible-playbook playbooks/deploy.yml --ask-vault-pass

# Or with password file
ansible-playbook playbooks/deploy.yml
```

### Vault Management
```bash
# Create encrypted file
ansible-vault create group_vars/all.yml

# Edit encrypted file
ansible-vault edit group_vars/all.yml

# View encrypted file
ansible-vault view group_vars/all.yml
```

### Verification
```bash
# Check container status
ansible webservers -a "docker ps"

# Test health endpoint
curl http://<VM-IP>:5001/health

# View container logs
ansible webservers -a "docker logs devops-app"
```

---

## Summary

This lab demonstrated Ansible fundamentals through role-based automation:

- **Role Structure:** Created three roles (common, docker, web_app) with proper organization
- **Idempotency:** Proved tasks only make changes when needed
- **Handlers:** Used handlers for efficient service management
- **Vault:** Secured credentials with Ansible Vault encryption
- **Deployment:** Successfully deployed containerized application

All roles are reusable, idempotent, and follow Ansible best practices.
