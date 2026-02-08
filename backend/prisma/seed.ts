import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const regions = [
  // North India
  { name: 'Delhi', state: 'Delhi', latitude: 28.6139, longitude: 77.2090 },
  { name: 'Noida', state: 'Uttar Pradesh', latitude: 28.5355, longitude: 77.3910 },
  { name: 'Gurgaon', state: 'Haryana', latitude: 28.4595, longitude: 77.0266 },
  { name: 'Jaipur', state: 'Rajasthan', latitude: 26.9124, longitude: 75.7873 },
  { name: 'Lucknow', state: 'Uttar Pradesh', latitude: 26.8467, longitude: 80.9462 },
  { name: 'Chandigarh', state: 'Chandigarh', latitude: 30.7333, longitude: 76.7794 },
  
  // West India
  { name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777 },
  { name: 'Pune', state: 'Maharashtra', latitude: 18.5204, longitude: 73.8567 },
  { name: 'Ahmedabad', state: 'Gujarat', latitude: 23.0225, longitude: 72.5714 },
  { name: 'Surat', state: 'Gujarat', latitude: 21.1702, longitude: 72.8311 },
  
  // South India
  { name: 'Bangalore', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946 },
  { name: 'Chennai', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707 },
  { name: 'Hyderabad', state: 'Telangana', latitude: 17.3850, longitude: 78.4867 },
  { name: 'Kochi', state: 'Kerala', latitude: 9.9312, longitude: 76.2673 },
  { name: 'Coimbatore', state: 'Tamil Nadu', latitude: 11.0168, longitude: 76.9558 },
  
  // East India
  { name: 'Kolkata', state: 'West Bengal', latitude: 22.5726, longitude: 88.3639 },
  { name: 'Bhubaneswar', state: 'Odisha', latitude: 20.2961, longitude: 85.8245 },
  { name: 'Patna', state: 'Bihar', latitude: 25.5941, longitude: 85.1376 },
  { name: 'Guwahati', state: 'Assam', latitude: 26.1445, longitude: 91.7362 },
  
  // Central India
  { name: 'Bhopal', state: 'Madhya Pradesh', latitude: 23.2599, longitude: 77.4126 },
  { name: 'Indore', state: 'Madhya Pradesh', latitude: 22.7196, longitude: 75.8577 },
  { name: 'Nagpur', state: 'Maharashtra', latitude: 21.1458, longitude: 79.0882 },
];

const categories = [
  { name: 'Politics', icon: '🏛️', color: '#EF4444' },
  { name: 'Business', icon: '💼', color: '#F59E0B' },
  { name: 'Sports', icon: '⚽', color: '#10B981' },
  { name: 'Entertainment', icon: '🎬', color: '#8B5CF6' },
  { name: 'Technology', icon: '💻', color: '#3B82F6' },
  { name: 'Lifestyle', icon: '🌟', color: '#EC4899' },
  { name: 'Career', icon: '📈', color: '#06B6D4' },
  { name: 'Education', icon: '📚', color: '#6366F1' },
  { name: 'Health', icon: '🏥', color: '#14B8A6' },
  { name: 'Philosophy', icon: '🤔', color: '#A855F7' },
  { name: 'History', icon: '📜', color: '#D97706' },
  { name: 'Environment', icon: '🌍', color: '#22C55E' },
  { name: 'Social Issues', icon: '🤝', color: '#F43F5E' },
  { name: 'Science', icon: '🔬', color: '#0EA5E9' },
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
