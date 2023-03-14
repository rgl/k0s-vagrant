FROM golang:1.20-bullseye AS build
WORKDIR /build
COPY go.* .
RUN go mod download
COPY *.go .
RUN CGO_ENABLED=0 go build -ldflags="-s"

FROM debian:bullseye-slim
COPY --from=build /build/example-app /app/
ENTRYPOINT ["/app/example-app"]
