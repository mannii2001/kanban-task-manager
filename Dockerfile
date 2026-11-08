FROM node:22-alpine AS builder

WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application source
COPY . .

# Build production application
RUN npm run build


# ==========================================
# Stage 2: Production Runtime Stage
# ==========================================

FROM nginxinc/nginx-unprivileged:alpine AS runtime

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy only production build artifacts
COPY --from=builder --chown=101:101 /app/dist/ /usr/share/nginx/html/

# Explicitly run as non-root user
USER 101:101

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/ || exit 1

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
