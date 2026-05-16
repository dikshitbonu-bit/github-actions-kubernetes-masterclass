# BEFORE: ~30 MB (alpine:3.23 + ca-certs + unstripped binary ~20 MB)
# AFTER:  ~19 MB (alpine:3.23 + ca-certs + stripped binary ~9 MB, ~37% smaller)

# Stage 1: Build
FROM golang:1.26-alpine AS builder

WORKDIR /app

# Cache dependency downloads — only re-runs when go.mod or go.sum change
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -trimpath -o skillpulse .

# Stage 2: Run — no Go toolchain, no build cache, only the compiled binary
FROM alpine:3.23

# hadolint ignore=DL3018
RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/skillpulse .

EXPOSE 8080

CMD ["./skillpulse"]
