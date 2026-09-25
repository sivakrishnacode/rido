# Rido admin panel (Next.js standalone). Build from the repo root (npm workspaces):
#   docker build -f apps/admin/Dockerfile -t rido-admin .
FROM node:24-alpine AS deps
WORKDIR /repo
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
COPY apps/admin/package.json apps/admin/
COPY apps/passenger/package.json apps/passenger/
COPY apps/driver/package.json apps/driver/
COPY packages/rido_ui/package.json packages/rido_ui/
COPY packages/rido_data/package.json packages/rido_data/
RUN npm ci --workspace=@rido/admin --include-workspace-root=false --no-audit --no-fund

FROM deps AS build
ENV NEXT_TELEMETRY_DISABLED=1
# Baked into the client bundle at build time: Google Maps JavaScript API browser key (restrict by HTTP referrer).
ARG NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY=
ENV NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY=${NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY}
COPY apps/admin apps/admin
WORKDIR /repo/apps/admin
RUN npx next build

FROM node:24-alpine AS runtime
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3001 HOSTNAME=0.0.0.0
WORKDIR /app
RUN apk add --no-cache tini && addgroup -S rido && adduser -S rido -G rido
# Standalone output keeps the monorepo layout: server.js lives in apps/admin/.
COPY --from=build --chown=rido:rido /repo/apps/admin/.next/standalone ./
COPY --from=build --chown=rido:rido /repo/apps/admin/.next/static ./apps/admin/.next/static
COPY --from=build --chown=rido:rido /repo/apps/admin/public ./apps/admin/public
USER rido
EXPOSE 3001
HEALTHCHECK --interval=15s --timeout=3s --start-period=15s --retries=5 \
  CMD wget -qO- http://127.0.0.1:3001/login > /dev/null || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "apps/admin/server.js"]
