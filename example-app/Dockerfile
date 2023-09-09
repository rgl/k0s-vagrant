FROM golang:1.21-bookworm AS build
WORKDIR /build
COPY go.* .
RUN go mod download
COPY *.go .
RUN CGO_ENABLED=0 go build -ldflags="-s"

FROM debian:bookworm-slim
COPY --from=build /build/example-app /app/
ENTRYPOINT ["/app/example-app"]
