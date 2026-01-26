# ============================================
# HISTEERIA BACKEND - PRODUCTION DOCKERFILE
# Optimized for minimal image size and fast startup
# ============================================

# Stage 1: Build
FROM golang:1.24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set timezone data for the final image
ENV TZ=UTC

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies (cached if go.mod/go.sum unchanged)
RUN go mod download && go mod verify

# Copy source code
COPY . .

# DEBUG: List files to ensure internal directories are copied
RUN ls -la /app/internal/auth /app/internal/storage || echo "Directories missing"
RUN go env

# Build with optimizations
# -ldflags="-s -w" strips debug symbols for smaller binary
# CGO_ENABLED=0 for static binary
# -trimpath removes build paths for reproducible builds
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.Version=1.0.0 -X main.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -trimpath \
    -o /app/histeeria-backend \
    .

# Stage 2: Runtime (minimal image)
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binary
COPY --from=builder /app/histeeria-backend /histeeria-backend

# Expose port (Render uses 10000)
EXPOSE 10000

# Set user to non-root for security
# Note: scratch doesn't have users, but the binary runs without root privileges

# Note: Health check is handled by Render's healthCheckPath in render.yaml
# Scratch images don't support shell-based HEALTHCHECK

# Run the application
ENTRYPOINT ["/histeeria-backend"]
