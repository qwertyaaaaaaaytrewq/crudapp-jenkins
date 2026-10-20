FROM node:18

WORKDIR /app

COPY ./api/package*.json ./
RUN npm config set fetch-retries 10 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    npm ci --prefer-offline --no-audit --no-fund --verbose

COPY ./api/ ./
COPY ./html/ /var/www/html/

RUN chmod -R 755 /app/uploads
RUN openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /app/server.key \
    -out /app/server.crt \
    -days 365 \
    -subj "/CN=localhost"
#EXPOSE 5000
EXPOSE 80 443
CMD ["node", "server.js"]