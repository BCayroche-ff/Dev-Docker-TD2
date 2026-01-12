# Dockerfile - ${{ values.serviceName }}
# Généré par le Golden Path Template TechMarket
# Bonnes pratiques: multi-stage, non-root, healthcheck

# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Production
FROM node:18-alpine AS production
WORKDIR /app

# Sécurité: utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

# Copier les dépendances depuis le builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Utiliser l'utilisateur non-root
USER nodejs

# Exposer le port
EXPOSE ${{ values.port }}

# Health check intégré
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:${{ values.port }}/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Démarrage
CMD ["node", "server.js"]
