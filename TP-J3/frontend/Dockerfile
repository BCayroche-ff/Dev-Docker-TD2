# Stage 1: Build
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Build argument for API URL
ARG REACT_APP_API_URL=http://localhost:5000

# Copy package files
COPY package.json ./

# Install all dependencies (including devDependencies for build)
RUN npm install

# Copy application source code
COPY . .

# Build the React application with the API URL
RUN REACT_APP_API_URL=${REACT_APP_API_URL} npm run build

# Stage 2: Production
FROM nginx:alpine

# SECURITY: Configure NGINX to run as non-root user
# Create nginx user and group (if not exists)
RUN addgroup -g 101 -S nginx || true && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx || true

# Copy built files from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Change ownership of necessary directories to nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d

# Create PID file directory and set permissions
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# SECURITY: Expose port 8080 instead of 80 (non-root can't bind to <1024)
# NOTE: You must update nginx.conf to listen on 8080
# NOTE: You must update the K8s Service targetPort to 8080
EXPOSE 8080

# SECURITY: Switch to non-root user
USER nginx

# Start nginx (default command from nginx:alpine image)
CMD ["nginx", "-g", "daemon off;"]
