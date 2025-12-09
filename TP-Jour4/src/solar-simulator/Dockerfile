# =====================================================
# Solar Simulator - Dockerfile optimise
# Image cible: < 200MB
# =====================================================

# Stage 1: Build et installation des dependances
FROM node:20-alpine AS builder

WORKDIR /app

# Copier les fichiers de dependances
COPY package*.json ./

# Installer uniquement les dependances de production
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Image de production
FROM node:20-alpine

# Labels pour documentation
LABEL maintainer="TP Master 2 GitOps"
LABEL description="Simulateur de fermes solaires pour monitoring"
LABEL version="1.0.0"

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000
ENV DATA_DIR=/app/data

WORKDIR /app

# Creer un utilisateur non-root pour la securite
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

# Copier les node_modules du stage builder
COPY --from=builder /app/node_modules ./node_modules

# Copier le code source
COPY --chown=nodejs:nodejs src/ ./src/
COPY --chown=nodejs:nodejs package.json ./

# Copier les donnees CSV
COPY --chown=nodejs:nodejs data/ ./data/

# Passer a l'utilisateur non-root
USER nodejs

# Exposer le port
EXPOSE 3000

# Health check integre
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Commande de demarrage
CMD ["node", "src/index.js"]
