# syntax=docker/dockerfile:1

# --- Build stage -------------------------------------------------------------
FROM dart:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY bin ./bin
COPY lib ./lib
COPY migrations ./migrations

RUN dart compile exe bin/server.dart -o /app/server

# --- Runtime stage -----------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system arij \
    && useradd --system --gid arij --home-dir /app --shell /usr/sbin/nologin arij

WORKDIR /app

# Dart runtime shared libraries required by the AOT-compiled executable.
COPY --from=build /runtime/ /
COPY --from=build --chown=arij:arij /app/server /app/server
COPY --from=build --chown=arij:arij /app/migrations /app/migrations

USER arij

ENV SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8080 \
    MIGRATIONS_DIR=/app/migrations

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/app/server"]
