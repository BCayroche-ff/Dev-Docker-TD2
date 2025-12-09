# Stage 1: Production
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files first (for layer caching optimization)
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy application source code
COPY . .

# Change ownership to node user (non-root)
# The node user (UID 1000) is already created in node:alpine base image
RUN chown -R node:node /app

# Expose application port
EXPOSE 5000

# Set environment to production
ENV NODE_ENV=production

# SECURITY: Switch to non-root user
# Running as non-root prevents privilege escalation attacks
USER node

# Start the application
CMD ["npm", "start"]
