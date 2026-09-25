# Rido API image. Build from the repo root (npm workspaces):
#   docker build -f apps/api/Dockerfile -t rido-api .
FROM node:24-alpine AS deps
WORKDIR /repo
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
COPY apps/passenger/package.json apps/passenger/
COPY apps/driver/package.json apps/driver/
COPY packages/rido_ui/package.json packages/rido_ui/
COPY packages/rido_data/package.json packages/rido_data/
RUN npm ci --workspace=@rido/api --include-workspace-root=false --no-audit --no-fund

FROM deps AS build
COPY apps/api apps/api
WORKDIR /repo/apps/api
# prisma generate reads prisma.config.ts, which needs a URL (not used to connect).
RUN DATABASE_URL=postgresql://build:build@localhost:5432/build npx prisma generate && npx nest build

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /repo
RUN apk add --no-cache tini && addgroup -S rido && adduser -S rido -G rido
COPY --from=build /repo/node_modules ./node_modules
COPY --from=build /repo/apps/api/node_modules ./apps/api/node_modules
COPY --from=build /repo/apps/api/package.json ./apps/api/package.json
COPY --from=build /repo/apps/api/dist ./apps/api/dist
COPY --from=build /repo/apps/api/prisma ./apps/api/prisma
COPY --from=build /repo/apps/api/prisma.config.ts ./apps/api/prisma.config.ts
COPY --from=build /repo/apps/api/src/generated ./apps/api/src/generated
# The seed script (tsx) imports these source files directly.
COPY --from=build /repo/apps/api/src/modules/subscriptions/plan-prices.ts ./apps/api/src/modules/subscriptions/plan-prices.ts
COPY --from=build /repo/apps/api/src/modules/geo/h3.util.ts ./apps/api/src/modules/geo/h3.util.ts
COPY apps/api/docker-entrypoint.sh ./apps/api/docker-entrypoint.sh
WORKDIR /repo/apps/api
USER rido
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=5 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
ENTRYPOINT ["/sbin/tini", "--", "sh", "./docker-entrypoint.sh"]
