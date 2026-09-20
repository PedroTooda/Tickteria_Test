FROM node:22-slim
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /repo

# Manifests primeiro: aproveita o cache do npm ci
COPY package.json package-lock.json tsconfig.base.json ./
COPY apps/api/package.json apps/api/
COPY apps/worker/package.json apps/worker/
COPY apps/web/package.json apps/web/
COPY packages/core/package.json packages/core/
COPY packages/infra/package.json packages/infra/
RUN npm ci

COPY . .

ARG BUILD_TARGET=backend
ARG NEXT_PUBLIC_API_URL=http://localhost:3001
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

RUN npm run db:generate && npm run build:packages && \
    if [ "$BUILD_TARGET" = "web" ]; then \
      npm run build -w @tickteira/web; \
    else \
      npm run build:backend; \
    fi

ENV NODE_ENV=production
