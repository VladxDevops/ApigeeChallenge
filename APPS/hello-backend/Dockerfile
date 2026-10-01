# syntax=docker/dockerfile:1

############################
# Stage 1: build
############################
FROM node:20-slim AS build

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY src/ ./src/

############################
# Stage 2: runtime
############################
FROM node:20-slim AS runtime

RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 --gid appgroup --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

COPY --from=build --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=build --chown=appuser:appgroup /app/package.json ./package.json
COPY --from=build --chown=appuser:appgroup /app/src ./src

USER 10001

EXPOSE 8080

ENTRYPOINT ["node", "src/index.js"]
