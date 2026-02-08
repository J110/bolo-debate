#!/bin/bash

echo "🚀 Setting up Bolo Debate for local development..."
echo ""

# Navigate to project root
cd "$(dirname "$0")"

# Backend setup
echo "📦 Setting up backend..."
cd backend

# Install dependencies
echo "Installing Node.js dependencies..."
npm install

# Copy SQLite schema
echo "Configuring SQLite database..."
cp prisma/schema.sqlite.prisma prisma/schema.prisma

# Generate Prisma client
echo "Generating Prisma client..."
npx prisma generate

# Create database and run migrations
echo "Creating database..."
npx prisma db push

# Seed the database
echo "Seeding database with regions and categories..."
npx tsx prisma/seed.ts

echo ""
echo "✅ Backend setup complete!"
echo ""

# Go back to root
cd ..

# Flutter setup
echo "📱 Setting up Flutter app..."
cd apps/flutter_app

# Get Flutter dependencies
echo "Installing Flutter dependencies..."
flutter pub get

echo ""
echo "✅ Flutter setup complete!"
echo ""

cd ../..

echo "=========================================="
echo "🎉 Setup complete! To run the app:"
echo ""
echo "1. Start the backend:"
echo "   cd bolo-debate/backend && npm run dev"
echo ""
echo "2. In a new terminal, run Flutter:"
echo "   cd bolo-debate/apps/flutter_app && flutter run"
echo ""
echo "Or run Flutter for web:"
echo "   flutter run -d chrome"
echo "=========================================="
