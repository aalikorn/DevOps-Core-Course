import os
import socket
import platform
import logging
import threading
from pathlib import Path
from datetime import datetime, timezone
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from pythonjsonlogger import jsonlogger
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create JSON formatter
formatter = jsonlogger.JsonFormatter(
    '%(asctime)s %(levelname)s %(name)s %(module)s %(message)s'
)

# Use StreamHandler
logHandler = logging.StreamHandler()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)

app = FastAPI(
    title="DevOps Info Service",
    description="DevOps course info service",
    version="1.0.0"
)

# Define Prometheus metrics
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)

HTTP_REQUESTS_IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "HTTP requests currently being processed"
)

@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):
    """Middleware to record Prometheus metrics for each request."""
    method = request.method
    path = request.url.path
    
    # Track requests in progress
    HTTP_REQUESTS_IN_PROGRESS.inc()
    
    start_time = time.time()
    try:
        response = await call_next(request)
        status_code = str(response.status_code)
        
        # Record metrics (success)
        HTTP_REQUESTS_TOTAL.labels(method=method, endpoint=path, status=status_code).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(method=method, endpoint=path).observe(time.time() - start_time)
        
        return response
    except Exception as e:
        # Record metrics (error)
        HTTP_REQUESTS_TOTAL.labels(method=method, endpoint=path, status="500").inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(method=method, endpoint=path).observe(time.time() - start_time)
        raise e
    finally:
        HTTP_REQUESTS_IN_PROGRESS.dec()

@app.get("/metrics")
async def metrics():
    """Endpoint to expose Prometheus metrics."""
    from fastapi.responses import Response
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Application start time for uptime calculation
START_TIME = datetime.now(timezone.utc)

# --- Visits counter ---
VISITS_FILE = os.getenv("VISITS_FILE", "/data/visits")
_visits_lock = threading.Lock()


def _read_visits() -> int:
    """Read the current visit count from the persistent file."""
    try:
        return int(Path(VISITS_FILE).read_text().strip())
    except (FileNotFoundError, ValueError):
        return 0


def _write_visits(count: int) -> None:
    """Atomically write the visit count to the persistent file."""
    path = Path(VISITS_FILE)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(str(count))
    tmp.replace(path)

def get_uptime():
    """Calculate the uptime of the application."""
    delta = datetime.now(timezone.utc) - START_TIME
    seconds = int(delta.total_seconds())
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    return {
        'seconds': seconds,
        'human': f"{hours} hours, {minutes} minutes"
    }

def get_system_info():
    """Collect system information."""
    return {
        "hostname": socket.gethostname(),
        "platform": platform.system(),
        "platform_version": platform.version(),
        "architecture": platform.machine(),
        "cpu_count": os.cpu_count(),
        "python_version": platform.python_version()
    }

@app.get("/")
async def index(request: Request):
    """Main endpoint - returns service and system information."""
    logger.info(f"Request: {request.method} {request.url.path}")

    # Increment persistent visits counter
    with _visits_lock:
        count = _read_visits() + 1
        _write_visits(count)
    
    uptime = get_uptime()
    system_info = get_system_info()
    
    response_data = {
        "service": {
            "name": "devops-info-service",
            "version": "1.0.0",
            "description": "DevOps course info service",
            "framework": "FastAPI"
        },
        "system": system_info,
        "runtime": {
            "uptime_seconds": uptime['seconds'],
            "uptime_human": uptime['human'],
            "current_time": datetime.now(timezone.utc).isoformat(),
            "timezone": "UTC"
        },
        "request": {
            "client_ip": request.client.host if request.client else "unknown",
            "user_agent": request.headers.get('user-agent', 'unknown'),
            "method": request.method,
            "path": request.url.path
        },
        "visits": count,
        "endpoints": [
            {"path": "/", "method": "GET", "description": "Service information"},
            {"path": "/health", "method": "GET", "description": "Health check"},
            {"path": "/visits", "method": "GET", "description": "Visit counter"}
        ]
    }
    return response_data


@app.get("/visits")
async def visits():
    """Return the current visit count."""
    count = _read_visits()
    return {"visits": count}

@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": get_uptime()['seconds']
    }

@app.exception_handler(404)
async def not_found_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=404,
        content={"error": "Not Found", "message": "Endpoint does not exist"},
    )

@app.exception_handler(500)
async def internal_server_error_handler(request: Request, exc: Exception):
    logger.error(f"Internal Server Error: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal Server Error", "message": "An unexpected error occurred"},
    )

if __name__ == "__main__":
    import uvicorn
    
    HOST = os.getenv('HOST', '0.0.0.0')  # nosec B104
    PORT = int(os.getenv('PORT', 5001))
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting server on {HOST}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
