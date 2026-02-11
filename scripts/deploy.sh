#!/bin/bash

# Bolo Debate Deployment Script
# Usage: ./scripts/deploy.sh [backend|web|ios|android|all]

set -e

# Configuration
API_URL="${API_URL:-https://bolo-debate-api-xxxxx.run.app}"
WS_URL="${WS_URL:-wss://bolo-debate-api-xxxxx.run.app/ws}"
LIVEKIT_URL="${LIVEKIT_URL:-wss://bolo-debate-chldbsx4.livekit.cloud}"
GCP_PROJECT="${GCP_PROJECT:-bolo-debate-prod}"
GCP_REGION="${GCP_REGION:-asia-south1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Deploy Backend to Cloud Run
deploy_backend() {
    echo_info "Deploying backend to Cloud Run..."
    cd backend
    
    # Verify gcloud is configured
    if ! gcloud config get-value project &> /dev/null; then
        echo_error "GCP project not configured. Run: gcloud config set project $GCP_PROJECT"
        exit 1
    fi
    
    # Submit build
    gcloud builds submit --config=cloudbuild.yaml
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe bolo-debate-api --region=$GCP_REGION --format='value(status.url)')
    echo_info "Backend deployed to: $SERVICE_URL"
    
    cd ..
}

# Deploy Web to Firebase Hosting
deploy_web() {
    echo_info "Deploying web to Firebase Hosting..."
    cd apps/flutter_app
    
    # Build Flutter web
    echo_info "Building Flutter web..."
    flutter build web --release \
        --dart-define=API_BASE_URL=$API_URL \
        --dart-define=WS_URL=$WS_URL \
        --dart-define=LIVEKIT_URL=$LIVEKIT_URL
    
    # Deploy to Firebase
    echo_info "Deploying to Firebase..."
    firebase deploy --only hosting
    
    cd ../..
}

# Build iOS
build_ios() {
    echo_info "Building iOS app..."
    cd apps/flutter_app
    
    # Install pods
    cd ios && pod install && cd ..
    
    # Build IPA
    flutter build ipa --release \
        --dart-define=API_BASE_URL=$API_URL \
        --dart-define=WS_URL=$WS_URL \
        --dart-define=LIVEKIT_URL=$LIVEKIT_URL
    
    echo_info "iOS build complete: build/ios/ipa/bolo_debate.ipa"
    echo_warn "Upload to App Store Connect manually or use: xcrun altool --upload-app"
    
    cd ../..
}

# Build Android
build_android() {
    echo_info "Building Android app..."
    cd apps/flutter_app
    
    # Build App Bundle
    flutter build appbundle --release \
        --dart-define=API_BASE_URL=$API_URL \
        --dart-define=WS_URL=$WS_URL \
        --dart-define=LIVEKIT_URL=$LIVEKIT_URL
    
    echo_info "Android build complete: build/app/outputs/bundle/release/app-release.aab"
    echo_warn "Upload to Google Play Console manually"
    
    cd ../..
}

# Main
case "$1" in
    backend)
        deploy_backend
        ;;
    web)
        deploy_web
        ;;
    ios)
        build_ios
        ;;
    android)
        build_android
        ;;
    all)
        deploy_backend
        deploy_web
        build_ios
        build_android
        ;;
    *)
        echo "Usage: $0 [backend|web|ios|android|all]"
        echo ""
        echo "Commands:"
        echo "  backend  - Deploy backend to Google Cloud Run"
        echo "  web      - Build and deploy web to Firebase Hosting"
        echo "  ios      - Build iOS app (IPA)"
        echo "  android  - Build Android app (AAB)"
        echo "  all      - Deploy everything"
        echo ""
        echo "Environment variables:"
        echo "  API_URL      - Backend API URL (default: $API_URL)"
        echo "  WS_URL       - WebSocket URL (default: $WS_URL)"
        echo "  LIVEKIT_URL  - LiveKit server URL (default: $LIVEKIT_URL)"
        echo "  GCP_PROJECT  - GCP project ID (default: $GCP_PROJECT)"
        echo "  GCP_REGION   - GCP region (default: $GCP_REGION)"
        exit 1
        ;;
esac

echo_info "Deployment complete!"
