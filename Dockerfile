FROM node:20-alpine
WORKDIR /app/backend

# Install dependencies (prod only)
COPY backend/package*.json ./
COPY backend/prisma ./prisma
RUN npm install --omit=dev

# Copy source code
COPY backend/. .

# Generate Prisma Client (fetch CLI ephemerally)
RUN npx --yes prisma@6.16.2 generate

EXPOSE 8080
CMD ["node","src/server.js"]
