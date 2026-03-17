import { PrismaClient } from '@prisma/client'
import * as bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  const hashedPassword = await bcrypt.hash('admin123', 12)

  await prisma.user.upsert({
    where: { email: 'admin@admin.com' },
    update: {},
    create: {
      email: 'admin@admin.com',
      password: hashedPassword,
      name: 'Admin User',
      role: 'admin',
    },
  })

  await prisma.user.upsert({
    where: { email: 'dev@admin.com' },
    update: {},
    create: {
      email: 'dev@admin.com',
      password: await bcrypt.hash('dev123', 12),
      name: 'Developer User',
      role: 'developer',
    },
  })

  console.log('Database seeded successfully')
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
