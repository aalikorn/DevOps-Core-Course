# Lab 6: Advanced Ansible & CI/CD – Submission

**Name:** Daria Nikolaeva  
**Date:** 2026-03-05  
**Lab Points:** 10 + 0 bonus

---

## Task 1: Blocks & Tags (2 pts)

### Implementation

- **Role `common`** (`roles/common/tasks/main.yml`):
  - I split the logic into two main blocks:
    - A **packages** block (tags: `packages`, `common`) which:
      - updates the apt cache;
      - installs a list of common packages from the `common_packages` variable;
      - in the `always` section writes a small log file `/tmp/common_role_completion.log` with the timestamp from `ansible_date_time.iso8601`.
    - A **user management** block (tags: `users`, `common`) which:
      - ensures that the `deploy_user` exists with a home directory and shell;
      - adds this user to the `sudo` group;
      - in the `always` section writes `/tmp/user_management_completion.log`.
  - For both blocks I apply `become: true` on the block level so I do not have to repeat privilege escalation on every task.
  - Each block has a `rescue` section:
    - for packages: it prints a debug message, runs `apt-get update --fix-missing`, and retries package installation;
    - for users: it prints a debug message so the playbook continues but I still see that something went wrong.

- **Role `docker`** (`roles/docker/tasks/main.yml`):
  - A **Docker preparation** block (tags: `docker_install`, `docker`) which:
    - installs required apt dependencies (transport, certificates, curl, gnupg, lsb-release);
    - creates `/etc/apt/keyrings`;
    - adds the official Docker GPG key;
    - adds the Docker apt repository.
    - In the `rescue` section it logs a message, waits 10 seconds, runs `apt update` again and retries adding the key.
  - A **Docker engine installation** block (tags: `docker_install`, `docker`) which:
    - installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`;
    - installs Python libraries `docker` and `docker-compose` via `pip`;
    - in the `always` section guarantees that the `docker` service is enabled and started.
  - A **Docker configuration** block (tags: `docker_config`, `docker`) which:
    - adds `docker_user` to the `docker` group and notifies the `restart docker` handler;
    - creates `/etc/docker/daemon.json` with simple log rotation settings and also notifies the handler;
    - uses a `rescue` section to log that default settings will be used if configuration fails;
    - in the `always` section writes `/tmp/docker_installation_completion.log`.

### Tag Strategy

- For the `common` role:
  - `packages` – all package installation tasks.
  - `users` – all user management tasks.
  - `common` – the whole role.
- For the `docker` role:
  - `docker` – the whole role.
  - `docker_install` – everything related to installing Docker.
  - `docker_config` – configuration tasks only.

### Execution Examples

To verify that blocks and tags work as expected I use commands like:

- `ansible-playbook playbooks/provision.yml --tags "docker"` – run only the Docker-related tasks.
- `ansible-playbook playbooks/provision.yml --skip-tags "common"` – skip the common system configuration.
- `ansible-playbook playbooks/provision.yml --tags "packages"` – focus on the package installation logic and check idempotency.
- `ansible-playbook playbooks/provision.yml --list-tags` – see the complete list of tags exposed by my roles.

### Research Answers

- **How do tags behave inside blocks?**  
  A tag defined on a block is inherited by all tasks inside that block. It is still possible to add extra tags on individual tasks if needed.

- **What happens if the `rescue` block also fails?**  
  If any task inside the `rescue` section fails (and the failure is not ignored), the whole block is considered failed and control does not go to the `always` section.

- **Can blocks be nested?**  
  Yes, Ansible supports nested blocks, but deep nesting usually makes playbooks harder to read. In this lab I keep blocks flat and group tasks logically instead.

---

## Task 2: Docker Compose (3 pts)

### Template Structure

- The `web_app` role uses the template `roles/web_app/templates/docker-compose.yml.j2`. The template is parameterized with:
  - `app_name` – used as the service and container name;
  - `docker_image` and `docker_tag` – the Docker image and tag to deploy (for example `${dockerhub_username}/devops-app-python:latest`);
  - `app_port` and `app_internal_port` – host/container ports mapping;
  - optional environment variables which can be passed and stored in Vault if they are secrets.
- The template defines a service with `restart: unless-stopped`, which is a good default for a long‑running web application.

The role defaults in `roles/web_app/defaults/main.yml` provide reasonable values so I can deploy with minimal extra configuration:

- `app_name: devops-app`
- `docker_image: "{{ dockerhub_username }}/devops-app-python"` (pointing at my Python app image)
- `docker_tag: latest`
- `app_port: 8000`
- `app_internal_port: 8000`
- `compose_project_dir: "/opt/{{ app_name }}"`
- `docker_compose_version: "3.8"`

### Role Dependencies

In `roles/web_app/meta/main.yml` I declare a dependency on the `docker` role. This guarantees that Docker is installed and configured before the application deployment runs, even if I include only the `web_app` role in a playbook. It also helps keep my playbooks short, because the sequencing is expressed via role metadata.

### Deployment Logic

The main deployment logic lives in `roles/web_app/tasks/main.yml`:

1. Log in to Docker Hub using `docker_login` with `no_log: true` so credentials are hidden from logs.
2. Create the application directory `{{ compose_project_dir }}`.
3. Render `docker-compose.yml` from the Jinja2 template into that directory.
4. Pull the latest version of the configured Docker image via `docker_image`.
5. Deploy the stack using `community.docker.docker_compose_v2` with:
   - `state: present`,
   - `pull: always`,
   - `recreate: smart`.
6. Wait until the application is listening on `app_port` using the `wait_for` module.
7. Call the `/health` endpoint via the `uri` module and retry a few times until it returns HTTP 200.
8. Print a short debug message that the application is healthy.

If anything fails inside the deployment block, the `rescue` section:

- prints an error message with a hint to inspect `docker-compose` logs;
- runs `docker ps -a` and shows the output;
- fails the play to make the problem visible.

The playbooks are:

- `playbooks/provision.yml` – applies `common` and `docker` roles to `webservers`;
- `playbooks/deploy.yml` – applies the `web_app` role to `webservers`.

### Before / After Comparison

Before using Docker Compose, the app could be started with a single `docker run` command (or a small shell script). That approach is easy for experiments, but it is hard to keep configuration in sync when there are multiple options (ports, environment variables, restart policy, volumes, etc.).

With Docker Compose:

- the configuration is fully declarative in `docker-compose.yml`;
- it is easy to see all settings in one place;
- the same role and template can be reused for more than one app;
- Ansible can manage the Compose project idempotently (running the playbook twice does not break anything).

I run `ansible-playbook playbooks/deploy.yml` several times to check idempotency:

- on the first run the directory is created, the file is templated and the container is started;
- on subsequent runs most tasks report `ok` (no change), which confirms that the state is stable.

---

## Task 3: Wipe Logic (1 pt)

### Implementation Details

- The main control variable is `web_app_wipe` in `roles/web_app/defaults/main.yml`:
  - default value is `false` so wipe is safe by default;
  - there is an additional `web_app_remove_images` flag which can be used later to also remove images.
- The wipe tasks live in `roles/web_app/tasks/wipe.yml`. The block:
  - stops and removes containers using Docker Compose;
  - removes the `docker-compose.yml` file;
  - removes the whole application directory `{{ compose_project_dir }}`;
  - optionally can be extended to remove Docker images when `web_app_remove_images: true`;
  - prints a debug message that the application was wiped.
- The wipe block is tagged with `web_app_wipe` and additionally guarded by `when: web_app_wipe | bool`, so it never runs accidentally.
- In `roles/web_app/tasks/main.yml` I include the wipe tasks at the top:
  - `include_tasks: wipe.yml` with tag `web_app_wipe`;
  - the deployment block runs afterwards.

This placement allows a “clean reinstall” scenario: wipe first, deploy second, all from a single playbook run.

### Usage Scenarios

I designed the wipe logic for four main scenarios:

1. **Normal deploy (no wipe)**  
   ```bash
   ansible-playbook ansible/playbooks/deploy.yml
   ```
   In this case the `web_app_wipe` tag is not used and the variable is `false`, so the wipe tasks are skipped.

2. **Wipe only**  
   ```bash
   ansible-playbook ansible/playbooks/deploy.yml \
     -e "web_app_wipe=true" \
     --tags web_app_wipe
   ```
   Only the wipe tasks run, deployment is not executed.

3. **Clean reinstall (wipe → deploy)**  
   ```bash
   ansible-playbook ansible/playbooks/deploy.yml \
     -e "web_app_wipe=true"
   ```
   First the wipe block runs (because the variable is `true`), then the normal deployment block runs in the same play.

4. **Safety check**  
   If I forget to pass the variable or the tag, the combination of `when: web_app_wipe | bool` and the dedicated `web_app_wipe` tag prevents destructive actions from running by mistake.

### Research Answers

- **Why use both a variable and a tag?**  
  This is a double safety mechanism. The tag requires an explicit `--tags web_app_wipe` on the command line, and the variable requires an explicit `-e "web_app_wipe=true"`. Without both, destructive tasks will not run.

- **Why not just use the `never` tag?**  
  The special `never` tag is harder to work with and does not combine nicely with the “clean reinstall” flow. A dedicated tag plus a boolean variable is more explicit and easier to understand for anyone reading the playbook.

- **Why does the wipe block execute before deployment?**  
  Running wipe first ensures that a clean reinstall works correctly: old containers and files are removed before new ones are created.

---

## Task 4: CI/CD (3 pts)

### Workflow Architecture

The Ansible CI/CD workflow is defined in `.github/workflows/ansible-deploy.yml`.

- **Triggers:**
  - `push` and `pull_request` to the `master` branch when files under `ansible/**` or the workflow itself change.
- **Jobs:**
  1. **`lint`**:
     - runs on `ubuntu-latest`;
     - installs `ansible` and `ansible-lint` using pip;
     - runs `ansible-lint playbooks/*.yml` from the `ansible` directory.
  2. **`deploy`**:
     - runs only after `lint` succeeds;
     - uses secrets to configure SSH and Vault;
     - prepares a simple inventory file with a `webservers` group;
     - runs `playbooks/provision.yml` and `playbooks/deploy.yml`;
     - verifies that the app responds on `/` and `/health` using `curl`.

The deploy job is also guarded so that it only runs when all required secrets are present, which helps keep CI green while configuration is being finished.

### Secrets Configuration

The following GitHub Actions secrets are used:

- `VM_HOST` – IP or hostname of the target VM.
- `VM_USER` – SSH user (for example `ubuntu`).
- `SSH_PRIVATE_KEY` – private SSH key with access to the VM.
- `ANSIBLE_VAULT_PASSWORD` – password used to decrypt Vault files (for example `group_vars/all.yml`).

In the workflow these secrets are passed via environment variables and temporary files. The Vault password is written into `/tmp/vault_pass` and then removed after the playbooks finish.

### Evidence

To validate the CI/CD setup I will:

- configure the secrets in the repository settings;
- make a small change under `ansible/` and push it;
- check the “Ansible Deployment” workflow in the Actions tab:
  - confirm that `lint` passes without errors from `ansible-lint`;
  - confirm that `deploy` runs the playbooks successfully;
  - make sure that the final `curl` checks to `/` and `/health` succeed.

Optionally I can add a status badge to `README.md`:

```markdown
[![Ansible Deployment](https://github.com/<user>/<repo>/actions/workflows/ansible-deploy.yml/badge.svg)](https://github.com/<user>/<repo>/actions/workflows/ansible-deploy.yml)
```

---

## Task 5: Documentation

This file, `ansible/docs/LAB06.md`, serves as the main documentation for Lab 6. It explains:

- the structure of the Ansible project (roles, playbooks, variables);
- how blocks and tags are used in the `common` and `docker` roles;
- how the `web_app` role uses Docker Compose and role dependencies;
- how the wipe logic is implemented and protected;
- how the Ansible CI/CD workflow in GitHub Actions is organized.

In addition to the text, terminal outputs and screenshots from my runs can be attached to the corresponding sections when I submit the lab.

---

## Bonus Part 1: Multi-App (1.5 pts)

The multi‑app bonus part (reusing the same `web_app` role for several applications with separate `vars` files and playbooks) is not implemented in this lab. However, the current design of the `web_app` role and the Docker Compose template already supports this scenario in the future by overriding variables like `app_name`, `docker_image` and `app_port`.

---

## Bonus Part 2: Multi-App CI/CD (1 pt)

The second bonus part (separate or matrix CI/CD workflows for multiple apps) is also not implemented here. It can be built later on top of the existing workflow by adding extra jobs or workflows that call different Ansible playbooks and use path filters to trigger only when the corresponding app changes.

---

## Summary

In this lab I turned my Ansible setup into a more production‑ready automation: I organized tasks into blocks with clear tags, migrated application deployment to Docker Compose, and added safe wipe logic for cleaning up deployments when needed. On top of that I integrated Ansible with GitHub Actions so that provisioning and deployment can run automatically after changes are pushed. The main takeaways for me are how to use blocks/rescue/always in Ansible, how to keep playbooks idempotent, and how to connect configuration management with CI/CD.

