# DevOps Info Service (Python)

![Python CI](https://github.com/dashanikolaeva/DevOps-Core-Course/actions/workflows/python-ci.yml/badge.svg)
[![codecov](https://codecov.io/gh/dashanikolaeva/DevOps-Core-Course/graph/badge.svg?token=YOUR_TOKEN)](https://codecov.io/gh/dashanikolaeva/DevOps-Core-Course)


A simple web application build with FastAPI that reports system information and health status.

## Overview

This service provides detailed information about its runtime environment, including system specs, uptime, and request details.

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

- `GET /`: Returns comprehensive service and system information.
- `GET /health`: Simple health check endpoint for monitoring.

## Configuration

The application can be configured using the following environment variables:

| Variable | Default   | Description      |
|----------|-----------|------------------|
| `HOST`   | `0.0.0.0` | Bind address     |
| `PORT`   | `5001`    | Port to listen on |
| `DEBUG`  | `False`   | Enable debug mode |

## Docker

### Building the Image Locally

```bash
docker build -t <your-username>/app_python:latest ./app_python
```

### Running a Container

```bash
docker run -d -p 5001:5001 --name app_python_container <your-username>/app_python:latest
```

### Pulling from Docker Hub

```bash
docker pull <your-username>/app_python:latest
```
