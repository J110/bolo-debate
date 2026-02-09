import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Simplified regions - 6 major metros + National for pan-India discussions
const regions = [
  { name: 'National', state: 'India', latitude: 20.5937, longitude: 78.9629 }, // Pan-India discussions
  { name: 'Delhi NCR', state: 'Delhi', latitude: 28.6139, longitude: 77.2090 },
  { name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777 },
  { name: 'Bangalore', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946 },
  { name: 'Hyderabad', state: 'Telangana', latitude: 17.3850, longitude: 78.4867 },
  { name: 'Chennai', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707 },
  { name: 'Kolkata', state: 'West Bengal', latitude: 22.5726, longitude: 88.3639 },
];

// Simplified categories - 5 most engaging topics
const categories = [
  { name: 'Politics', icon: '🏛️', color: '#EF4444' },
  { name: 'Technology', icon: '💻', color: '#3B82F6' },
  { name: 'Business', icon: '💼', color: '#F59E0B' },
  { name: 'Sports', icon: '⚽', color: '#10B981' },
  { name: 'Entertainment', icon: '🎬', color: '#8B5CF6' },
];

async function main() {
  console.log('Seeding database...');

  // Create regions
  console.log('Creating regions...');
  for (const region of regions) {
    await prisma.region.upsert({
      where: { name_state: { name: region.name, state: region.state } },
      update: region,
      create: region,
    });
  }
  console.log(`Created ${regions.length} regions`);

  // Create categories
  console.log('Creating categories...');
  for (const category of categories) {
    await prisma.category.upsert({
      where: { name: category.name },
      update: category,
      create: category,
    });
  }
  console.log(`Created ${categories.length} categories`);

  // Create a bot user for AI messages
  console.log('Creating bot user...');
  const existingBot = await prisma.user.findUnique({ where: { username: 'bolo_bot' } });
  if (!existingBot) {
    await prisma.user.create({
      data: {
        username: 'bolo_bot',
        displayName: 'Bolo Bot',
        avatarUrl: null,
      },
    });
  }

  console.log('Seeding completed!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
