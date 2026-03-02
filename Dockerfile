# -----------------------------
# 1️⃣ Dependencies stage
# -----------------------------
    FROM node:20-alpine AS deps

    WORKDIR /app
    
    # Enable corepack
    RUN corepack enable
    
    COPY package.json pnpm-lock.yaml ./
   
    
    # Install dependencies
    RUN pnpm install --frozen-lockfile
    
    
    # -----------------------------
    # 2️⃣ Builder stage
    # -----------------------------
    FROM node:20-alpine AS builder
    
    # Accept build argument 
    ARG BASE_URL
    ARG SITE_NAME
    ARG META_PIXEL_ID
    
    WORKDIR /app
    
    RUN corepack enable
    
    # Reuse installed deps
    COPY --from=deps /app/node_modules ./node_modules
    COPY . .

    # Set the base URL for the API
    ENV VITE_API_BASE_URL=${BASE_URL}
    ENV VITE_API_SITE_NAME=${SITE_NAME}
    ENV VITE_META_PIXEL_ID=${META_PIXEL_ID}
    
    # Build app
    RUN pnpm run build
    
    
    # -----------------------------
    # 3️⃣ Runtime (minimal)
    # -----------------------------
    FROM nginx:1.25-alpine AS runner
    
    # Create non-root user and remove default nginx config
    RUN addgroup -S app && adduser -S app -G app && \
        rm /etc/nginx/conf.d/default.conf
    
    # Copy custom nginx config
    COPY nginx.conf /etc/nginx/nginx.conf
    COPY default.conf /etc/nginx/conf.d/default.conf
    
    # Copy only the build output (NO source, NO deps)
    COPY --from=builder /app/dist /usr/share/nginx/html
    
    # Set permissions
    RUN chown -R app:app \
        /var/cache/nginx \
        /usr/share/nginx/html \
        /tmp
    
    USER app
    
    EXPOSE 80
    
    CMD ["nginx", "-g", "daemon off;"]
    