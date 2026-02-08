#!/bin/bash

# Bolo Debate Quick Deploy Script
# This script helps deploy to Render, Fly.io, and Vercel

set -e

echo "🚀 Bolo Debate Deployment Script"
echo "================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

echo "Checking prerequisites..."
check_command git
check_command fly || echo "  Install: curl -L https://fly.io/install.sh | sh"
check_command vercel || echo "  Install: npm i -g vercel"
check_command flutter

echo ""

# Get deployment info
read -p "Enter your Render API URL (e.g., https://bolo-debate-api.onrender.com): " RENDER_API_URL
read -p "Enter your Fly.io LiveKit URL (e.g., wss://bolo-debate-livekit.fly.dev): " LIVEKIT_URL

if [ -z "$RENDER_API_URL" ]; then
    RENDER_API_URL="https://bolo-debate-api.onrender.com"
fi

if [ -z "$LIVEKIT_URL" ]; then
    LIVEKIT_URL="wss://bolo-debate-livekit.fly.dev"
fi

echo ""
echo "Configuration:"
echo "  API URL: $RENDER_API_URL"
echo "  LiveKit URL: $LIVEKIT_URL"
echo ""

# Menu
PS3="Select deployment target: "
options=("Deploy LiveKit (Fly.io)" "Deploy Backend (Push to GitHub for Render)" "Deploy Frontend (Vercel)" "Deploy All" "Exit")

select opt in "${options[@]}"
do
    case $opt in
        "Deploy LiveKit (Fly.io)")
            echo ""
            echo -e "${YELLOW}Deploying LiveKit to Fly.io...${NC}"
            cd livekit-fly
            fly auth login 2>/dev/null || true
            
            if ! fly apps list | grep -q "bolo-debate-livekit"; then
                echo "Creating Fly.io app..."
                fly launch --name bolo-debate-livekit --region sin --no-deploy
            fi
            
            fly deploy
            echo -e "${GREEN}✓ LiveKit deployed!${NC}"
            echo "  URL: wss://bolo-debate-livekit.fly.dev"
            cd ..
            ;;
            
        "Deploy Backend (Push to GitHub for Render)")
            echo ""
            echo -e "${YELLOW}Preparing backend for Render...${NC}"
            
            if [ ! -d ".git" ]; then
                git init
            fi
            
            git add .
            git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
            
            if ! git remote | grep -q "origin"; then
                echo ""
                echo -e "${YELLOW}No remote origin set.${NC}"
                echo "1. Create a GitHub repo at https://github.com/new"
                echo "2. Run: git remote add origin https://github.com/YOUR_USERNAME/bolo-debate.git"
                echo "3. Run: git push -u origin main"
            else
                git push origin main
                echo -e "${GREEN}✓ Code pushed to GitHub!${NC}"
                echo "  Render will auto-deploy if connected"
            fi
            ;;
            
        "Deploy Frontend (Vercel)")
            echo ""
            echo -e "${YELLOW}Building Flutter web...${NC}"
            cd apps/flutter_app
            
            flutter build web --release \
                --dart-define=API_BASE_URL="$RENDER_API_URL" \
                --dart-define=LIVEKIT_URL="$LIVEKIT_URL"
            
            echo ""
            echo -e "${YELLOW}Deploying to Vercel...${NC}"
            cd build/web
            vercel --prod
            
            echo -e "${GREEN}✓ Frontend deployed!${NC}"
            cd ../../../..
            ;;
            
        "Deploy All")
            echo ""
            echo -e "${YELLOW}Starting full deployment...${NC}"
            
            # LiveKit
            echo ""
            echo "Step 1/3: Deploying LiveKit..."
            cd livekit-fly
            fly auth login 2>/dev/null || true
            if ! fly apps list 2>/dev/null | grep -q "bolo-debate-livekit"; then
                fly launch --name bolo-debate-livekit --region sin --no-deploy 2>/dev/null || true
            fi
            fly deploy || echo "LiveKit deployment failed - continue manually"
            cd ..
            
            # Backend
            echo ""
            echo "Step 2/3: Pushing backend to GitHub..."
            git add . 2>/dev/null || true
            git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || echo "No changes"
            git push origin main 2>/dev/null || echo "Push to GitHub manually"
            
            # Frontend
            echo ""
            echo "Step 3/3: Building and deploying frontend..."
            cd apps/flutter_app
            flutter build web --release \
                --dart-define=API_BASE_URL="$RENDER_API_URL" \
                --dart-define=LIVEKIT_URL="$LIVEKIT_URL"
            cd build/web
            vercel --prod || echo "Vercel deployment needs manual setup"
            cd ../../../..
            
            echo ""
            echo -e "${GREEN}✓ Deployment complete!${NC}"
            ;;
            
        "Exit")
            echo "Goodbye!"
            exit 0
            ;;
            
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    echo "Press Enter to continue..."
    read
done
