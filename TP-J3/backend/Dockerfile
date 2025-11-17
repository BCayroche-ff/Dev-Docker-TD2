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

# Expose application port
EXPOSE 5000

# Set environment to production
ENV NODE_ENV=production

# Start the application
CMD ["npm", "start"]
