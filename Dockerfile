FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
WORKDIR /usr/share/nginx/html
RUN rm -rf *
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

# docker build --no-cache -t harishnshetty/amazon-frontend:latest .

# docker run -d -p 8080:80 harishnshetty/amazon-frontend:latest

# docker push harishnshetty/amazon-frontend:latest
