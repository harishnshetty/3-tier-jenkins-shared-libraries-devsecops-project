# Stage 1: Build Stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Runtime Stage
FROM node:20-alpine
WORKDIR /app

# Create non-root user
RUN adduser -D appuser && chown -R appuser /app

# Copy built artifacts from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY . .
# Set ownership
RUN chown -R appuser /app

USER appuser

EXPOSE 4000
CMD ["node", "index.js"]