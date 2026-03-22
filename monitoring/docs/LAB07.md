# Lab 07: Observability & Logging with Loki Stack

In this lab, I deployed a centralized logging and observability stack using Grafana Loki, Promtail, and Grafana dashboards. The goal was to aggregate logs from our containerized applications (both Python and Go apps) using JSON structured logging, allowing us to build dashboards to analyze the incoming requests and errors dynamically.

## Architecture

The stack runs locally inside a `docker-compose.yml` environment located in the `monitoring` directory. 
It consists of:
- **Loki** storage backend containing Log streams.
- **Promtail** daemon designed to collect docker container logs via the host docker UNIX socket `/var/run/docker.sock` and dispatching them towards Loki.
- **Grafana** dashboard application for querying LogQL directly.
- **App-Python & App-Go** microservices, each connected to the `logging` network and configured to export JSON logs dynamically. Promtail strictly scrapes applications broadcasting the `logging=promtail` docker label.

## Setup Guide

To spin up the environment:
1. Clone my repository and navigate into the `monitoring/` directory.
2. Provide a `.env` file containing your desired Grafana credentials. I provided a `.env.example` file to show the structure:
   ```env
   GF_SECURITY_ADMIN_USER=admin
   GF_SECURITY_ADMIN_PASSWORD=supersecret
   ```
3. Run `docker compose up -d` (Docker compose v2) to build and deploy Loki, Promtail, Grafana, and our two microservices side-by-side.
4. Access Grafana at `http://localhost:3000` using the credentials supplied in the `.env` file. You should see the auto-provisioned Loki data source and "Application Logs" dashboard.

## Configuration Highlights

**Loki (`loki/config.yml`)**: 
I configured Loki 3.0 to leverage TSDB (Time Series Database) alongside basic filesystem object storage which is 10x faster for localized query indexing. Inside `limits_config`, log retention was enforced to `168h` (7 days), actively utilizing the `compactor` to cleanup aged data automatically.

**Promtail (`promtail/config.yml`)**:
For Promtail, I created `docker_sd_configs` specifying `/var/run/docker.sock` as the host. The most crucial part was adding `relabel_configs` to catch `__meta_docker_container_name` to define the container label, filter strictly by `__meta_docker_container_label_logging: promtail`, and extract the `app` descriptor (like `devops-python` or `devops-go`) from docker labels for easy Grafana classification.

## Application Logging

Getting uniform JSON logging in both applications was an interesting task:
- **Python App**: I overhauled the standard Python `logging.basicConfig` to use `python-json-logger`. I instantiated a `JsonFormatter` and applied it natively to a `StreamHandler` connected to the root logger in `app.py`.
- **Go App**: For the Go application, I transitioned from the conventional `log` package to the newer standard library `log/slog` which arrived in Go 1.21. By establishing a `slog.NewJSONHandler(os.Stdout, nil)` globally, the app natively dumps all initialization sequences and handled requests into an easily parsable JSON map. 

## Dashboards and LogQL

Inside Grafana, I crafted an **"Application Logs"** dashboard consisting of 4 distinct panels focusing on querying my apps:
1. **Logs Table**: A central view utilizing `{app=~"devops-.*"}` logic to view all unstructured logs descending.
2. **Request Rate**: A clean time series graph applying `sum by (app) (rate({app=~"devops-.*"} [1m]))` visualizing traffic volume separated by application.
3. **Error Logs**: Filtered Logs panel narrowing `{app=~"devops-.*"} | json | level="ERROR"`, ensuring critical stack-traces surface properly.
4. **Log Level Distribution**: A Pie chart aggregating `sum by (level) (count_over_time({app=~"devops-.*"} | json [5m]))` to summarize info vs errors.

## Production Readiness Config

To make the system production-ready, several steps were taken conceptually beyond a development state:
- **Resource Constraints**: In `docker-compose.yml`, I designated explicit `limits` and `reservations` for CPU and Memory allocation over all stack services to ensure the docker engine isn't brought down if Loki experiences rapid bloat.
- **Security Check**: Rather than anonymous admin rights, Grafana actively mounts hidden variables from a `.env` lookup avoiding committing hardcoded keys directly onto the Git repository structure. 
- **Health Checks**: Loki and Grafana encompass docker `healthcheck` specifications actively probing `/api/health` and `/ready` with `wget` allowing dependencies and health routines to evaluate.

## Automated Ansible Deployment

As a bonus task, I structured an Ansible automation role inside `ansible/roles/monitoring` utilizing `community.docker.docker_compose_v2`. Templates (`.j2`) were integrated replacing all port parameters, memory scopes, and schema variants into variable structures (`defaults/main.yml`). You can seamlessly deploy this to external hosts by executing the `playbooks/deploy-monitoring.yml` context against an SSH-accessible inventory!

## Challenges

I encountered some challenges utilizing Loki 3.0 configuration structure. In earlier Loki versions, `boltdb` was predominantly used as the config schema, which meant moving towards schema `v13` required understanding specific period setups mapped accurately inside `tsdb` caching logic. Setting up log levels natively in Go also forced a switch over towards `slog` which is slightly different in API methodology compared to legacy format integrations but resulted in vastly cleaner serialization outputs.

---
### Testing Commands
```bash
# Validations locally
docker compose up -d
docker compose ps # Wait for healthchecks to switch to 'healthy'

# Generate traffic
for i in {1..20}; do curl http://localhost:8000/; done
for i in {1..20}; do curl http://localhost:8001/; done
```
