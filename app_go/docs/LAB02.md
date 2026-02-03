# Lab 02 — Docker Containerization (Go Bonus)

## 1. Multi-Stage Build Strategy

For the Go application, I implemented a multi-stage build to achieve a minimal production image.

### Stage 1: Builder
Uses the full `golang:1.23-alpine` image to compile the source code into a static binary.
```dockerfile
FROM golang:1.23-alpine AS builder
...
RUN CGO_ENABLED=0 GOOS=linux go build -o main main.go
```

### Stage 2: Runtime
Uses a minimal `alpine:3.20` image as the base and only copies the compiled binary from the builder stage.
```dockerfile
FROM alpine:3.20
...
COPY --from=builder /app/main .
```

## 2. Size Comparison & Analysis

| Stage | Image Size |
|-------|------------|
| Builder Stage (`golang: alpine`) | ~300MB+ |
| **Final Image (`alpine`)** | **16.3MB** |

**Why it matters:**
- **Disk Usage:** Smaller images take up less space on the host and in the registry.
- **Boot Time:** Smaller images are pulled and started faster.
- **Security:** The final image contains no build tools, no shell with full utilities (if using scratch/minimal alpine), and fewer packages, significantly reducing the attack surface.

## 3. Build & Run Process

### Build Output
```bash
$ docker build -t aalikorn/app_go:latest ./app_go
[+] Building 24.3s (16/16) FINISHED
 => [builder 1/5] FROM docker.io/library/golang:1.23-alpine
 => [stage-1 1/4] FROM docker.io/library/alpine:3.20
 => [builder 5/5] RUN CGO_ENABLED=0 GOOS=linux go build -o main main.go
 => [stage-1 4/4] COPY --from=builder /app/main .
 => exporting to image
 => => naming to docker.io/aalikorn/app_go:latest
```

### Run Output
```bash
$ docker run -d -p 8081:8080 --name app_go_container aalikorn/app_go:latest
dc2557f7be214820e0a64d57fe675a5e19d7f296bd0791cad55c23e8b10d6dd9
```

### Testing Endpoints
```bash
$ curl -s http://localhost:8081/health
{"status":"healthy","timestamp":"2026-02-03T18:28:13Z","uptime_seconds":2}
```

## 4. Technical Explanation

- **CGO_ENABLED=0:** This environment variable tells Go to build a static binary that doesn't depend on C libraries. This is essential for running the binary in a minimal image like `alpine` or `scratch` which might not have the standard C library (glibc).
- **AS builder:** This allows us to name the first stage and reference it in the `COPY --from=builder` instruction in the second stage.
- **Non-root user:** Even in a minimal image, I still create a non-root user `appuser` for security.

## 5. Security Benefits
By separating the build environment from the runtime environment, we ensure that:
1. The compiler and other build tools are not available in the production environment.
2. The image size is minimized, reducing the number of binaries that could have vulnerabilities.
3. The attack surface is restricted to only what's necessary to run the application binary.
