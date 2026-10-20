
# syntax=docker/dockerfile:1.7

FROM node:18

WORKDIR /app

COPY ./api/package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm config set fetch-retries 20 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 600000 && \
    npm config set maxsockets 2 && \
    npm ci --prefer-offline --no-audit --no-fund

COPY ./api/ ./

EXPOSE 80

CMD ["node", "server.js"]
