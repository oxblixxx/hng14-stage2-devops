# ---------- Builder ----------
FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

# ---------- Production deps only ----------
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

# ---------- Final ----------
FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

RUN apk add --no-cache curl

USER node

# Copy only production node_modules
COPY --from=deps /app/node_modules /app/node_modules

# Copy app source (no dev deps)
COPY --from=builder /app /app

EXPOSE 3002

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3002/health || exit 1

CMD ["npm", "start"]
