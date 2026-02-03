# Stage 1: Build the application
FROM golang:1.23-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go.mod and go.sum (if exists)
COPY go.mod ./
# RUN go mod download # Not needed if no dependencies yet

# Copy source code
COPY main.go .

# Build the application
# CGO_ENABLED=0 for a static binary
RUN CGO_ENABLED=0 GOOS=linux go build -o main main.go

# Stage 2: Create the final image
FROM alpine:3.20

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main .

# Switch to non-root user
USER appuser

# Expose the port
EXPOSE 8080

# Command to run the application
CMD ["./main"]
