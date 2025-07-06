# Build stage
FROM golang:1.22-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy go.mod and go.sum (if they exist)
COPY . .

# Build the application
# CGO_ENABLED=0 creates a statically linked binary
# -ldflags="-w -s" reduces binary size by removing debug information
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server

# Final stage
FROM scratch

# Copy the binary from builder
COPY --from=builder /app/server /server

# Set environment variable (can be overridden at runtime)
ENV LISTEN_PORT=8080

# Expose the port
EXPOSE 8080

# Run the binary
ENTRYPOINT ["/server"] 