FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

# package-lock.json이 없으므로 npm install 사용
RUN npm install

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

# package-lock.json이 없으므로 npm install 사용
RUN npm install --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 8080

CMD ["npm", "start"]
