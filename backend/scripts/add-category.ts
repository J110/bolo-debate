/**
 * Script to add a new category to the topic generation system
 * 
 * Usage:
 *   npx ts-node scripts/add-category.ts "CategoryName" "🎯" "Category description"
 * 
 * Example:
 *   npx ts-node scripts/add-category.ts "Health" "🏥" "Health and wellness topics"
 */

import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

interface GenericTopicsData {
  version: string;
  lastUpdated: string;
  topics: Array<{
    id: string;
    category: string;
    title: string;
    titleHindi: string;
    sideA: string;
    sideB: string;
    sideAHindi: string;
    sideBHindi: string;
    tags: string[];
  }>;
}

async function addCategory(name: string, icon: string, description: string) {
  console.log(`\n🚀 Adding new category: ${name}\n`);

  // Step 1: Check if category already exists
  const existing = await prisma.category.findFirst({
    where: { name }
  });

  if (existing) {
    console.log(`✅ Category "${name}" already exists in database (ID: ${existing.id})`);
  } else {
    // Create category in database
    const category = await prisma.category.create({
      data: { name, icon, description }
    });
    console.log(`✅ Created category "${name}" in database (ID: ${category.id})`);
  }

  // Step 2: Check generic-topics.json
  const jsonPath = path.join(__dirname, '../src/data/generic-topics.json');
  const jsonData: GenericTopicsData = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  
  const existingTopics = jsonData.topics.filter(t => t.category === name);
  
  if (existingTopics.length > 0) {
    console.log(`✅ Found ${existingTopics.length} existing generic topics for "${name}"`);
  } else {
    console.log(`⚠️  No generic topics found for "${name}" in generic-topics.json`);
    console.log(`   Add topics manually with this structure:\n`);
    
    const template = {
      id: `${name.toLowerCase()}-001`,
      category: name,
      title: "Your debate question here?",
      titleHindi: "हिंदी में प्रश्न?",
      sideA: "Side A",
      sideB: "Side B",
      sideAHindi: "पक्ष A",
      sideBHindi: "पक्ष B",
      tags: ["evergreen", name.toLowerCase()]
    };
    
    console.log(JSON.stringify(template, null, 2));
  }

  // Step 3: Check trending.ts keywords
  const trendingPath = path.join(__dirname, '../src/services/trending.ts');
  const trendingContent = fs.readFileSync(trendingPath, 'utf-8');
  
  if (trendingContent.includes(`${name}:`)) {
    console.log(`✅ Category keywords exist in trending.ts`);
  } else {
    console.log(`⚠️  No keywords found for "${name}" in trending.ts`);
    console.log(`   Add to CATEGORY_KEYWORDS:\n`);
    console.log(`   ${name}: ['keyword1', 'keyword2', 'keyword3'],\n`);
  }

  // Step 4: Summary
  console.log('\n📋 Summary:');
  console.log('─'.repeat(50));
  
  const checks = [
    { name: 'Database category', done: true },
    { name: 'Generic topics (15+ recommended)', done: existingTopics.length >= 15 },
    { name: 'Trending keywords', done: trendingContent.includes(`${name}:`) }
  ];
  
  checks.forEach(check => {
    console.log(`   ${check.done ? '✅' : '⚠️ '} ${check.name}`);
  });
  
  const allDone = checks.every(c => c.done);
  
  if (allDone) {
    console.log('\n✨ Category is fully configured!');
    console.log('   The scheduler will automatically create rooms for this category.');
  } else {
    console.log('\n📝 Action items remaining:');
    if (existingTopics.length < 15) {
      console.log(`   - Add ${15 - existingTopics.length}+ generic topics to generic-topics.json`);
    }
    if (!trendingContent.includes(`${name}:`)) {
      console.log('   - Add classification keywords to trending.ts');
    }
  }

  console.log('\n📖 See ADDING_NEW_CATEGORIES.md for detailed instructions.\n');
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log(`
Usage: npx ts-node scripts/add-category.ts "CategoryName" ["🎯"] ["Description"]

Arguments:
  CategoryName  - Required. The name of the category (e.g., "Health")
  Icon          - Optional. Emoji icon for the category (default: "📚")
  Description   - Optional. Brief description of the category

Examples:
  npx ts-node scripts/add-category.ts "Health"
  npx ts-node scripts/add-category.ts "Health" "🏥" "Health and wellness debates"
  `);
  process.exit(1);
}

const categoryName = args[0];
const icon = args[1] || '📚';
const description = args[2] || `${categoryName} category for debates`;

addCategory(categoryName, icon, description)
  .then(() => prisma.$disconnect())
  .catch((error) => {
    console.error('Error:', error);
    prisma.$disconnect();
    process.exit(1);
  });
