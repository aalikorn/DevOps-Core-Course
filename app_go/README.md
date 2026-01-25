# DevOps Info Service (Go)

A simple web application built with Go's standard library (`net/http`) that reports system information and health status.

## Overview

This service provides detailed information about its runtime environment, including system specs, uptime, and request details.

## Prerequisites

- Go 1.21+

## Installation & Running

```bash
go run main.go
```

Or with custom configuration:

```bash
PORT=9090 HOST=127.0.0.1 go run main.go
```

## API Endpoints

- `GET /`: Returns comprehensive service and system information.
- `GET /health`: Simple health check endpoint for monitoring.

## Configuration

The application can be configured using the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST`   | `0.0.0.0` | Bind address |
| `PORT`   | `8080`    | Port to listen on |
