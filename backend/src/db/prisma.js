import { PrismaClient } from '@prisma/client';

// Ensure a single PrismaClient instance in dev to avoid exhausting connections
const globalForPrisma = globalThis;

const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

export default prisma;
