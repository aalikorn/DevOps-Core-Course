# Use a specific version of Python slim image
FROM python:3.13-slim

# Set environment variables
# Prevent Python from writing .pyc files to disk
ENV PYTHONDONTWRITEBYTECODE=1
# Prevent Python from buffering stdout and stderr
ENV PYTHONUNBUFFERED=1

# Create a non-root user and group
# Using a fixed UID/GID for consistency
RUN groupadd -g 1000 appgroup && \
    useradd -u 1000 -g appgroup -m -s /bin/bash appuser

# Set working directory
WORKDIR /app

# Install dependencies
# Copy requirements first to leverage Docker layer caching
COPY --chown=appuser:appgroup requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
# Ensure the non-root user owns the files
COPY --chown=appuser:appgroup app.py .

# Switch to the non-root user
USER appuser

# Expose the port the app runs on
EXPOSE 5001

# Command to run the application
CMD ["python", "app.py"]
