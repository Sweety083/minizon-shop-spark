# ---------- Stage 1: Build the React/Vite app ----------
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the source code
COPY . .

# Build the app
RUN npm run build

# ---------- Stage 2: Serve using Nginx ----------
FROM nginx:alpine

# Copy the built app from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Optional: Copy custom Nginx configuration if it exists
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Optional: Health check endpoint
COPY public/health /usr/share/nginx/html/health

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
