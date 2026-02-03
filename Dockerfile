FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production \
    && npm cache clean --force
COPY . .

RUN adduser -m nodejs
RUN chown -R nodejs /app
USER nodejs

EXPOSE 4000
CMD ["node", "index.js"]

# docker build --no-cache -t harishnshetty/amazon-backend:latest .

# docker run -d -p 4000:4000 harishnshetty/amazon-backend:latest
