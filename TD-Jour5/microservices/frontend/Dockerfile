# Multi-stage build pour optimiser la taille de l'image
FROM node:18-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm install

# Copier le code source
COPY . .

# Build de l'application
RUN npm run build

# Stage de production avec nginx
FROM nginx:1.25-alpine

# Créer les dossiers avec les bonnes permissions pour l'utilisateur nginx (101)
RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    /tmp/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /tmp/nginx && \
    touch /tmp/nginx/nginx.pid && \
    chown nginx:nginx /tmp/nginx/nginx.pid && \
    # Modifier nginx.conf pour utiliser /tmp/nginx/nginx.pid
    sed -i 's|/var/run/nginx.pid|/tmp/nginx/nginx.pid|g' /etc/nginx/nginx.conf

# Copier la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copier les fichiers buildés depuis le stage builder
COPY --from=builder /app/build /usr/share/nginx/html

# S'assurer que les fichiers sont lisibles
RUN chown -R nginx:nginx /usr/share/nginx/html

# Exposer le port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

# Démarrer nginx
CMD ["nginx", "-g", "daemon off;"]
