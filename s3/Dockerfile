# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy source code
COPY . .

# Build static binary with reduced size
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server

# Final minimal image
FROM scratch

COPY --from=builder /app/server /server

ENV LISTEN_PORT=443
EXPOSE 443

ENTRYPOINT ["/server"] 