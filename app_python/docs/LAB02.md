# Lab 02 — Docker Containerization (Python)

## 1. Docker Best Practices Applied

### 1.1 Non-root User
I created a specific user and group inside the Dockerfile to avoid running the application as `root`.
```dockerfile
RUN groupadd -g 1000 appgroup && \
    useradd -u 1000 -g appgroup -m -s /bin/bash appuser
USER appuser
```
**Why it matters:** Running as root is a security risk. If an attacker compromises the application, they would have root access to the container and potentially the host. Using a non-root user follows the Principle of Least Privilege.

### 1.2 Layer Caching
I copied `requirements.txt` and installed dependencies BEFORE copying the application code.
```dockerfile
COPY --chown=appuser:appgroup requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=appuser:appgroup app.py .
```
**Why it matters:** Docker caches layers. If I change a line in `app.py` but don't change `requirements.txt`, Docker will reuse the cached layer for dependency installation, making rebuilds much faster.

### 1.3 .dockerignore
I added a `.dockerignore` file to exclude unnecessary files from the build context.
**Why it matters:** It reduces the size of the build context sent to the Docker daemon, speeds up builds, and prevents sensitive files (like `.git` or `.env`) from accidentally being included in the image.

### 1.4 Specific Base Image
I used `python:3.13-slim` instead of `python:latest` or `python:3.13`.
**Why it matters:** `slim` images are much smaller than full images, reducing the attack surface and bandwidth usage. Using a specific version ensures build reproducibility.

## 2. Image Information & Decisions

- **Base Image:** `python:3.13-slim`. Chosen for its balance between size and functionality. It contains the necessary runtime without the bloat of build tools.
- **Final Image Size:** 181MB.
- **Layer Structure:**
    - Base OS layer (Debian slim)
    - Python runtime layer
    - App user creation layer
    - Dependencies layer (pip install)
    - Application code layer
- **Optimization:** Used `--no-cache-dir` with pip to prevent caching wheels inside the image, further reducing size.

## 3. Build & Run Process

### Build Output
```bash
$ docker build -t aalikorn/app_python:latest ./app_python
[+] Building 52.1s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 853B
 => [internal] load .dockerignore
 => [internal] load metadata for docker.io/library/python:3.13-slim
 => [1/6] FROM docker.io/library/python:3.13-slim
 => [2/6] RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup -m -s /bin/bash appuser
 => [3/6] WORKDIR /app
 => [4/6] COPY --chown=appuser:appgroup requirements.txt .
 => [5/6] RUN pip install --no-cache-dir -r requirements.txt
 => [6/6] COPY --chown=appuser:appgroup app.py .
 => exporting to image
 => => writing image sha256:cf5999f0dfaf...
 => => naming to docker.io/aalikorn/app_python:latest
```

### Run Output
```bash
$ docker run -d -p 5001:5001 --name app_python_container aalikorn/app_python:latest
30009c3d0f9a42d9b3f954ec99b867fa160782f728f3a176b4337a2c1465db2f
```

### Testing Endpoints
```bash
$ curl -s http://localhost:5001/health
{"status":"healthy","timestamp":"2026-02-03T18:26:16.581736+00:00","uptime_seconds":9}
```

### Docker Hub
- **Repository URL:** [https://hub.docker.com/r/aalikorn/app_python](https://hub.docker.com/r/aalikorn/app_python)
- **Pushing the image:**
```bash
$ docker push aalikorn/app_python:latest
The push refers to repository [docker.io/aalikorn/app_python]
5f70bf18a086: Pushed
...
latest: digest: sha256:cf5999f0dfaf... size: 1370
```

## 4. Technical Analysis

- **Layer Order:** If I moved `COPY app.py .` before `RUN pip install`, every small change in the code would trigger a full re-installation of dependencies. The current order optimizes for development speed.
- **Security:** In addition to the non-root user, the slim base image reduces the number of pre-installed packages, thus reducing the number of potential vulnerabilities.
- **Environment Variables:** `PYTHONUNBUFFERED=1` ensures that logs are printed immediately to the console, which is crucial for container logging (e.g., `docker logs`).

## 5. Challenges & Solutions

- **Challenge:** Initial image was too large when using the full Python base image.
- **Solution:** Switched to `python:3.13-slim`, which brought the size down significantly while still providing all needed functionality.
- **Challenge:** Permission issues when copying files to the container.
- **Solution:** Used `--chown=appuser:appgroup` in the `COPY` instruction to ensure the non-root user has access to the app files.
