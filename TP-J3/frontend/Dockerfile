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

# Copy built files from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx (default command from nginx:alpine image)
CMD ["nginx", "-g", "daemon off;"]
