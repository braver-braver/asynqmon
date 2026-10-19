#
# First stage: 
# Building a frontend.
#

FROM node:22-bookworm-slim AS frontend
WORKDIR /static
# Required by legacy frontend dependencies when building with OpenSSL 3.
ENV NODE_OPTIONS=--openssl-legacy-provider
COPY ui .
RUN yarn install --frozen-lockfile --non-interactive && yarn build

#
# Second stage: 
# Building a backend.
#

FROM golang:1.24-alpine AS backend

# Move to a working directory (/build).
WORKDIR /build

# Copy and download dependencies.
COPY go.mod go.sum ./
RUN go mod download

# Copy a source code to the container.
COPY . .

# Copy frontend static files from /static to the root folder of the backend container.
COPY --from=frontend ["/static/build", "ui/build"]

# Set necessary environmet variables needed for the image and build the server.
ENV CGO_ENABLED=0 GOOS=linux

# Run go build (with ldflags to reduce binary size).
RUN go build -ldflags="-s -w" -o asynqmon ./cmd/asynqmon

#
# Third stage: 
# Creating and running a new scratch container with the backend binary.
#

FROM scratch

# Copy binary from /build to the root folder of the scratch container.
COPY --from=backend ["/build/asynqmon", "/"]

# Command to run when starting the container.
ENTRYPOINT ["/asynqmon"]
