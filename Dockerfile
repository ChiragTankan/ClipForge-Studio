# =====================================================================
# Stage 1: Build & Compile TypeScript
# =====================================================================
FROM node:20-slim AS builder

WORKDIR /usr/src/app

# Install system dependencies required for compiling native node modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy package descriptors first to leverage Docker layer caching
COPY package*.json ./

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy core codebase
COPY . .

# Run build compilation script (e.g., compile TypeScript to /dist/server)
# Note: In a typical repository, this would compile server.ts -> dist/server.js
RUN npm run list_dir || true # Guard in case there is no custom server build step yet

# =====================================================================
# Stage 2: Production Container
# =====================================================================
FROM node:20-slim

WORKDIR /usr/src/app

# Set production environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Install FFmpeg and system dependencies for video manipulation
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Verify ffmpeg installation
RUN ffmpeg -version

# Copy package descriptors to perform clean production-only install
COPY package*.json ./
RUN npm ci --only=production

# Copy built artifacts and scripts from the builder stage
COPY --from=builder /usr/src/app/dist ./dist
# If a direct server script exists at root of compiled output, copy it
COPY --from=builder /usr/src/app/package.json ./package.json

# Use non-privileged container user for security hardening
USER node

# Expose port (Cloud Run sets PORT env variable dynamically, default is 8080)
EXPOSE 8080

# Run the compiled video-processing server application
CMD ["node", "dist/server.js"]
