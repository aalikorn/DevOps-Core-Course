# DevOps Info Service (Python)

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

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST`   | `0.0.0.0` | Bind address |
| `PORT`   | `5000`    | Port to listen on |
| `DEBUG`  | `False`   | Enable debug mode |
