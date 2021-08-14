FROM golang:1.16-buster AS build
WORKDIR /build
COPY go.* .
RUN go mod download
COPY *.go .
RUN CGO_ENABLED=0 go build -ldflags="-s"

FROM debian:buster-slim
COPY --from=build /build/example-app /app/
ENTRYPOINT ["/app/example-app"]
