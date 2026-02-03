FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 4000
CMD ["node", "index.js"]

# docker build --no-cache -t harishnshetty/amazon-backend:latest .

# docker run -d -p 4000:4000 harishnshetty/amazon-backend:latest
