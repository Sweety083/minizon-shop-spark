# ===========================
# 🧩 Multi-stage Build for React App
# ===========================

# ---- Stage 1: Build the React app ----
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY bun.lockb ./

# Install dependencies (production only)
RUN npm ci --only=production

# Copy all source code
COPY . .

# Build the React app
RUN npm run build


# ---- Stage 2: Nginx for serving built files ----
FROM nginx:alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx configuration (ensure this file exists)
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Expose HTTP port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
