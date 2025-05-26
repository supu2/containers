# Stage 1: Build the Go app
FROM golang:1.22-alpine AS builder

# Install git (required if using Go modules with remote dependencies)
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the Go binary
RUN go build -o main .

# Stage 2: Create a minimal runtime image
FROM alpine:3.21

# Create a non-root user
RUN adduser -D -g '' appuser

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main http-logger

# Set executable permissions (optional if already executable)
RUN chmod +x ./http-logger

# Change to non-root user
USER appuser

# Run the Go app
ENTRYPOINT ["./http-logger"]
