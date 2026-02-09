import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Keep only these 6 major metros
const keepRegions = [
  'Delhi NCR', 'Delhi', // Accept both names
  'Mumbai',
  'Bangalore',
  'Hyderabad', 
  'Chennai',
  'Kolkata',
];

// Keep only these 5 engaging categories
const keepCategories = [
  'Politics',
  'Technology', 
  'Business',
  'Sports',
  'Entertainment',
];

async function cleanup() {
  console.log('🧹 Cleaning up database...\n');

  // Get all regions and categories
  const allRegions = await prisma.region.findMany();
  const allCategories = await prisma.category.findMany();

  console.log(`Found ${allRegions.length} regions, keeping ${keepRegions.length}`);
  console.log(`Found ${allCategories.length} categories, keeping ${keepCategories.length}\n`);

  // Find regions to delete
  const regionsToDelete = allRegions.filter(r => !keepRegions.includes(r.name));
  const categoriesToDelete = allCategories.filter(c => !keepCategories.includes(c.name));

  console.log(`Regions to remove: ${regionsToDelete.map(r => r.name).join(', ')}`);
  console.log(`Categories to remove: ${categoriesToDelete.map(c => c.name).join(', ')}\n`);

  // Delete rooms associated with regions/categories to be removed
  if (regionsToDelete.length > 0) {
    const regionIds = regionsToDelete.map(r => r.id);
    
    // Delete topic queue entries
    const deletedTopics = await prisma.topicQueue.deleteMany({
      where: { regionId: { in: regionIds } },
    });
    console.log(`Deleted ${deletedTopics.count} topic queue entries for removed regions`);

    // Delete rooms (this will cascade to participants, messages, reactions)
    const deletedRooms = await prisma.room.deleteMany({
      where: { regionId: { in: regionIds } },
    });
    console.log(`Deleted ${deletedRooms.count} rooms for removed regions`);

    // Delete regions
    const deletedRegions = await prisma.region.deleteMany({
      where: { id: { in: regionIds } },
    });
    console.log(`Deleted ${deletedRegions.count} regions`);
  }

  if (categoriesToDelete.length > 0) {
    const categoryIds = categoriesToDelete.map(c => c.id);

    // Delete topic queue entries
    const deletedTopics = await prisma.topicQueue.deleteMany({
      where: { categoryId: { in: categoryIds } },
    });
    console.log(`Deleted ${deletedTopics.count} topic queue entries for removed categories`);

    // Delete rooms
    const deletedRooms = await prisma.room.deleteMany({
      where: { categoryId: { in: categoryIds } },
    });
    console.log(`Deleted ${deletedRooms.count} rooms for removed categories`);

    // Delete categories
    const deletedCategories = await prisma.category.deleteMany({
      where: { id: { in: categoryIds } },
    });
    console.log(`Deleted ${deletedCategories.count} categories`);
  }

  // Rename "Delhi" to "Delhi NCR" if it exists
  await prisma.region.updateMany({
    where: { name: 'Delhi' },
    data: { name: 'Delhi NCR' },
  });

  console.log('\n✅ Cleanup complete!');
  
  // Show remaining
  const remainingRegions = await prisma.region.findMany();
  const remainingCategories = await prisma.category.findMany();
  
  console.log(`\nRemaining regions (${remainingRegions.length}): ${remainingRegions.map(r => r.name).join(', ')}`);
  console.log(`Remaining categories (${remainingCategories.length}): ${remainingCategories.map(c => c.name).join(', ')}`);
}

cleanup()
  .catch((e) => {
    console.error('Cleanup failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
