# DevOps Info Service (Python)

![Python CI](https://github.com/aalikorn/DevOps-Core-Course/actions/workflows/python-ci.yml/badge.svg)
![Coverage](https://codecov.io/gh/aalikorn/DevOps-Core-Course/branch/lab03/graph/badge.svg)


A simple web application build with FastAPI that reports system information and health status.

## Overview

This service provides detailed information about its runtime environment, including system specs, uptime, and request details. It also tracks the total number of visits to the root endpoint and persists the counter to disk so it survives container restarts.

## Prerequisites

- Python 3.11+
- Virtual environment (recommended)

## Installation

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Running the Application

```bash
python app.py
```

Or with custom configuration:

```bash
PORT=8080 HOST=127.0.0.1 python app.py
```

## API Endpoints

- `GET /`: Returns comprehensive service and system information (increments visit counter).
- `GET /health`: Simple health check endpoint for monitoring.
- `GET /visits`: Returns the current persistent visit count.
- `GET /metrics`: Prometheus metrics endpoint.

## Configuration

The application can be configured using the following environment variables:

| Variable      | Default      | Description                          |
|---------------|-------------|--------------------------------------|
| `HOST`        | `0.0.0.0`  | Bind address                         |
| `PORT`        | `5001`     | Port to listen on                    |
| `DEBUG`       | `False`    | Enable debug mode                    |
| `VISITS_FILE` | `/data/visits` | Path to the persistent visits file |

## Visits Counter

Every request to `GET /` increments a file-based counter stored at the path specified by `VISITS_FILE` (default `/data/visits`). The counter is read from disk on each request and written back atomically, so the value survives container restarts when the file is stored on a persistent volume.

The `GET /visits` endpoint returns the current count without incrementing it:

```json
{ "visits": 42 }
```

## Docker

### Building the Image Locally

```bash
docker build -t <your-username>/app_python:latest ./app_python
```

### Running a Container

```bash
docker run -d -p 5001:5001 --name app_python_container <your-username>/app_python:latest
```

### Docker Compose (with persistent volume)

```bash
cd app_python
docker compose up -d
```

The `docker-compose.yml` mounts `./data` into the container at `/data` so the visits counter persists across restarts:

```bash
# Access root a few times
curl http://localhost:5001/
curl http://localhost:5001/

# Check counter
curl http://localhost:5001/visits
# {"visits": 2}

# Restart container
docker compose restart

# Counter is preserved
curl http://localhost:5001/visits
# {"visits": 2}
```

### Pulling from Docker Hub

```bash
docker pull <your-username>/app_python:latest
```
