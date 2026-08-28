# Small Deno service: AI proxy, co-start rooms, entitlement verification.
# Personal history lives in the user's iCloud and never reaches this container.
FROM denoland/deno:alpine-2.1.4

WORKDIR /app
COPY src ./src
COPY certs ./certs

# Warm the module cache at build time so the container starts offline-fast.
RUN deno cache src/main.ts

USER deno
EXPOSE 8080

# Cap the heap: this shares a 2GB box with nginx, Postgres, Xray and sslh.
CMD ["deno", "run", "--allow-net", "--allow-env", "--v8-flags=--max-old-space-size=192", "src/main.ts"]
