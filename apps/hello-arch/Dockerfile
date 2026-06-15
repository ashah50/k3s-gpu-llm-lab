# Multi-arch build: buildx cross-compiles for each --platform using TARGETARCH.
# Build stage runs on the native BUILDPLATFORM (fast), output targets TARGET*.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w" -o /hello .

# Distroless static — tiny, no shell, same image manifest serves both arches.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /hello /hello
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/hello"]
