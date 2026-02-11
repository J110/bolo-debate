# Bolo Debate - Release Plan

A comprehensive guide for deploying Bolo Debate to production on Google Cloud Platform (GCP) and publishing to iOS App Store and Android Play Store.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [GCP Infrastructure Setup](#gcp-infrastructure-setup)
3. [Backend Deployment on GCP](#backend-deployment-on-gcp)
4. [Frontend Web Deployment](#frontend-web-deployment)
5. [iOS App Store Publishing](#ios-app-store-publishing)
6. [Android Play Store Publishing](#android-play-store-publishing)
7. [Post-Launch Checklist](#post-launch-checklist)
8. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Prerequisites

### Accounts Required

| Service | Purpose | Link |
|---------|---------|------|
| Google Cloud Platform | Backend hosting, database, storage | https://console.cloud.google.com |
| Apple Developer Account | iOS App Store publishing ($99/year) | https://developer.apple.com |
| Google Play Console | Android Play Store publishing ($25 one-time) | https://play.google.com/console |
| LiveKit Cloud | Real-time audio (or self-host) | https://livekit.io |
| Groq | AI topic generation (free tier) | https://console.groq.com |

### Tools Required

```bash
# Install Google Cloud SDK
brew install google-cloud-sdk

# Install Flutter
brew install flutter

# Install Xcode (Mac only, for iOS)
xcode-select --install

# Install Android Studio
# Download from https://developer.android.com/studio

# Install CocoaPods (for iOS)
sudo gem install cocoapods
```

### Environment Variables

Create a `.env.production` file with these values:

```env
# Database
DATABASE_URL=postgresql://user:password@host:5432/bolodebate

# Authentication
JWT_SECRET=your-secure-jwt-secret-min-32-chars
JWT_EXPIRES_IN=7d

# LiveKit
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
LIVEKIT_URL=wss://your-project.livekit.cloud

# AI Services
GROQ_API_KEY=your-groq-api-key

# Server
PORT=8080
HOST=0.0.0.0
NODE_ENV=production
```

---

## GCP Infrastructure Setup

### Step 1: Create GCP Project

```bash
# Login to GCP
gcloud auth login

# Create new project
gcloud projects create bolo-debate-prod --name="Bolo Debate Production"

# Set as default project
gcloud config set project bolo-debate-prod

# Enable billing (required for most services)
# Do this in the GCP Console: https://console.cloud.google.com/billing
```

### Step 2: Enable Required APIs

```bash
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudscheduler.googleapis.com \
  redis.googleapis.com
```

### Step 3: Set Up Cloud SQL (PostgreSQL)

```bash
# Create PostgreSQL instance
gcloud sql instances create bolo-debate-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=asia-south1 \
  --storage-type=SSD \
  --storage-size=10GB

# Set root password
gcloud sql users set-password postgres \
  --instance=bolo-debate-db \
  --password=YOUR_SECURE_PASSWORD

# Create database
gcloud sql databases create bolodebate --instance=bolo-debate-db

# Get connection name (save this)
gcloud sql instances describe bolo-debate-db --format='value(connectionName)'
# Output: bolo-debate-prod:asia-south1:bolo-debate-db
```

### Step 4: Set Up Redis (Optional, for caching)

```bash
# Create Redis instance
gcloud redis instances create bolo-debate-cache \
  --size=1 \
  --region=asia-south1 \
  --redis-version=redis_7_0
```

### Step 5: Store Secrets

```bash
# Create secrets
echo -n "your-jwt-secret" | gcloud secrets create JWT_SECRET --data-file=-
echo -n "your-livekit-api-key" | gcloud secrets create LIVEKIT_API_KEY --data-file=-
echo -n "your-livekit-api-secret" | gcloud secrets create LIVEKIT_API_SECRET --data-file=-
echo -n "your-groq-api-key" | gcloud secrets create GROQ_API_KEY --data-file=-
```

---

## Backend Deployment on GCP

### Option A: Cloud Run (Recommended - Serverless)

#### Step 1: Create Dockerfile

Create `backend/Dockerfile.production`:

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package*.json ./

EXPOSE 8080
CMD ["npm", "run", "start"]
```

#### Step 2: Create Cloud Build Config

Create `backend/cloudbuild.yaml`:

```yaml
steps:
  # Build the container image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/bolo-debate-api', '-f', 'Dockerfile.production', '.']
  
  # Push the container image to Container Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/bolo-debate-api']
  
  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'bolo-debate-api'
      - '--image'
      - 'gcr.io/$PROJECT_ID/bolo-debate-api'
      - '--region'
      - 'asia-south1'
      - '--platform'
      - 'managed'
      - '--allow-unauthenticated'
      - '--add-cloudsql-instances'
      - '$PROJECT_ID:asia-south1:bolo-debate-db'
      - '--set-env-vars'
      - 'NODE_ENV=production'
      - '--set-secrets'
      - 'JWT_SECRET=JWT_SECRET:latest,LIVEKIT_API_KEY=LIVEKIT_API_KEY:latest,LIVEKIT_API_SECRET=LIVEKIT_API_SECRET:latest,GROQ_API_KEY=GROQ_API_KEY:latest'
      - '--memory'
      - '512Mi'
      - '--cpu'
      - '1'
      - '--min-instances'
      - '1'
      - '--max-instances'
      - '10'

images:
  - 'gcr.io/$PROJECT_ID/bolo-debate-api'
```

#### Step 3: Deploy

```bash
cd backend

# Submit build
gcloud builds submit --config=cloudbuild.yaml

# Get the service URL
gcloud run services describe bolo-debate-api --region=asia-south1 --format='value(status.url)'
# Output: https://bolo-debate-api-xxxxx-el.a.run.app
```

### Option B: Google Kubernetes Engine (GKE) - For Scale

For larger deployments, use GKE:

```bash
# Create GKE cluster
gcloud container clusters create bolo-debate-cluster \
  --zone=asia-south1-a \
  --num-nodes=3 \
  --machine-type=e2-medium

# Get credentials
gcloud container clusters get-credentials bolo-debate-cluster --zone=asia-south1-a

# Apply Kubernetes manifests (create these separately)
kubectl apply -f k8s/
```

### Step 4: Run Database Migrations

```bash
# Connect to Cloud SQL and run migrations
gcloud sql connect bolo-debate-db --user=postgres

# Or use Cloud Run job
gcloud run jobs create migrate-db \
  --image=gcr.io/$PROJECT_ID/bolo-debate-api \
  --command="npx" \
  --args="prisma,db,push" \
  --set-cloudsql-instances=$PROJECT_ID:asia-south1:bolo-debate-db \
  --region=asia-south1

gcloud run jobs execute migrate-db --region=asia-south1
```

### Step 5: Set Up Cloud Scheduler (Cron Jobs)

```bash
# Create scheduler for topic generation (every hour)
gcloud scheduler jobs create http generate-topics \
  --location=asia-south1 \
  --schedule="0 * * * *" \
  --uri="https://YOUR_CLOUD_RUN_URL/api/admin/generate-topics" \
  --http-method=POST \
  --oidc-service-account-email=YOUR_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com

# Create scheduler for room lifecycle (every 5 minutes)
gcloud scheduler jobs create http room-lifecycle \
  --location=asia-south1 \
  --schedule="*/5 * * * *" \
  --uri="https://YOUR_CLOUD_RUN_URL/api/admin/room-lifecycle" \
  --http-method=POST \
  --oidc-service-account-email=YOUR_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com
```

---

## Frontend Web Deployment

### Option A: Firebase Hosting (Recommended)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (select Hosting)
cd apps/flutter_app
firebase init hosting

# Build Flutter web
flutter build web --release \
  --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL \
  --dart-define=WS_URL=wss://YOUR_CLOUD_RUN_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud

# Deploy
firebase deploy --only hosting
```

### Option B: Cloud Storage + Cloud CDN

```bash
# Create bucket
gsutil mb -l asia-south1 gs://bolo-debate-web

# Enable website hosting
gsutil web set -m index.html -e index.html gs://bolo-debate-web

# Build and upload
flutter build web --release \
  --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL \
  --dart-define=WS_URL=wss://YOUR_CLOUD_RUN_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud

gsutil -m cp -r build/web/* gs://bolo-debate-web/

# Make public
gsutil iam ch allUsers:objectViewer gs://bolo-debate-web

# Set up Cloud CDN (in GCP Console or via gcloud)
```

---

## iOS App Store Publishing

### Step 1: Apple Developer Setup

1. **Enroll in Apple Developer Program**
   - Go to https://developer.apple.com/programs/enroll/
   - Pay $99/year fee
   - Complete enrollment (can take 24-48 hours)

2. **Create App ID**
   - Go to https://developer.apple.com/account/resources/identifiers
   - Click "+" to create new identifier
   - Select "App IDs" → "App"
   - Bundle ID: `com.bolodebate.app` (must match your app)
   - Enable capabilities: Push Notifications, Associated Domains

3. **Create Provisioning Profile**
   - Go to https://developer.apple.com/account/resources/profiles
   - Create Distribution profile for App Store

### Step 2: App Store Connect Setup

1. **Create App in App Store Connect**
   - Go to https://appstoreconnect.apple.com
   - My Apps → "+" → New App
   - Fill in:
     - Platform: iOS
     - Name: Bolo Debate
     - Primary Language: English
     - Bundle ID: Select your App ID
     - SKU: bolodebate001

2. **Prepare App Information**
   - App Information:
     - Category: Social Networking
     - Content Rights: Does not contain third-party content
   - Pricing: Free (or set price tier)
   - Privacy Policy URL: https://bolodebate.com/privacy
   - Support URL: https://bolodebate.com/support

3. **Prepare Screenshots**
   Required sizes:
   - iPhone 6.7" (1290 x 2796 px) - iPhone 15 Pro Max
   - iPhone 6.5" (1284 x 2778 px) - iPhone 14 Plus
   - iPhone 5.5" (1242 x 2208 px) - iPhone 8 Plus
   - iPad Pro 12.9" (2048 x 2732 px)

### Step 3: Build iOS App

```bash
cd apps/flutter_app

# Update iOS configuration
# Edit ios/Runner/Info.plist - add required permissions:
```

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Bolo Debate needs microphone access to participate in voice debates</string>
<key>NSCameraUsageDescription</key>
<string>Bolo Debate needs camera access for video calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

```bash
# Install pods
cd ios && pod install && cd ..

# Build for release
flutter build ios --release \
  --dart-define=API_BASE_URL=https://YOUR_API_URL \
  --dart-define=WS_URL=wss://YOUR_API_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud

# Open in Xcode
open ios/Runner.xcworkspace
```

### Step 4: Archive and Upload

1. **In Xcode:**
   - Select "Any iOS Device" as build target
   - Product → Archive
   - Wait for archive to complete

2. **Distribute App:**
   - In Organizer, select the archive
   - Click "Distribute App"
   - Select "App Store Connect"
   - Choose "Upload"
   - Follow prompts

3. **Alternative: Using Command Line**

```bash
# Build IPA
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://YOUR_API_URL \
  --dart-define=WS_URL=wss://YOUR_API_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud

# Upload using xcrun
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/bolo_debate.ipa \
  --username "your-apple-id@email.com" \
  --password "app-specific-password"
```

### Step 5: Submit for Review

1. **In App Store Connect:**
   - Go to your app → App Store tab
   - Select the build you uploaded
   - Fill in "What's New" for this version
   - Answer export compliance questions
   - Submit for Review

2. **Review Timeline:**
   - First submission: 24-48 hours typically
   - Updates: 12-24 hours typically

### Common iOS Rejection Reasons & Fixes

| Reason | Solution |
|--------|----------|
| Missing privacy policy | Add privacy policy URL in App Store Connect |
| Incomplete metadata | Fill all required fields, add all screenshot sizes |
| Crashes on launch | Test thoroughly on real devices |
| Requesting unnecessary permissions | Only request permissions you use |
| Login required without guest mode | Add "Continue as Guest" option or explain in review notes |

---

## Android Play Store Publishing

### Step 1: Google Play Console Setup

1. **Create Developer Account**
   - Go to https://play.google.com/console
   - Pay $25 one-time fee
   - Complete account setup

2. **Create App**
   - Click "Create app"
   - Fill in:
     - App name: Bolo Debate
     - Default language: English
     - App or game: App
     - Free or paid: Free

### Step 2: Prepare Store Listing

1. **Main Store Listing:**
   - Short description (80 chars): "Join live voice debates on trending topics"
   - Full description (4000 chars): Detailed app description
   - App icon: 512 x 512 px PNG
   - Feature graphic: 1024 x 500 px
   - Screenshots: Min 2, max 8 per device type
     - Phone: Min 320px, max 3840px
     - 7" tablet: 1024 x 500 px
     - 10" tablet: 1024 x 500 px

2. **Content Rating:**
   - Complete IARC questionnaire
   - Expected rating: Teen (for social/debate content)

3. **Privacy & Data Safety:**
   - Privacy policy URL required
   - Complete data safety form:
     - Data collected: Email, name, voice data
     - Data shared: None
     - Security practices: Encrypted in transit

### Step 3: Generate Signing Key

```bash
# Generate upload key
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# Save keystore securely - you'll need it for every update!
```

Create `android/key.properties`:

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

Update `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### Step 4: Build Android App

```bash
cd apps/flutter_app

# Update Android configuration
# Edit android/app/src/main/AndroidManifest.xml - add permissions:
```

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://YOUR_API_URL \
  --dart-define=WS_URL=wss://YOUR_API_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud

# Output: build/app/outputs/bundle/release/app-release.aab

# Or build APK (for direct distribution)
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR_API_URL \
  --dart-define=WS_URL=wss://YOUR_API_URL/ws \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud
```

### Step 5: Upload to Play Console

1. **Production Release:**
   - Go to Release → Production
   - Create new release
   - Upload `app-release.aab`
   - Add release notes
   - Review and roll out

2. **Staged Rollout (Recommended):**
   - Start with 10% of users
   - Monitor crash rates and reviews
   - Gradually increase to 100%

### Step 6: App Signing by Google Play

- Enable "Google Play App Signing" (recommended)
- Upload your upload key certificate
- Google manages the app signing key

### Common Android Rejection Reasons & Fixes

| Reason | Solution |
|--------|----------|
| Policy violation | Review Google Play policies carefully |
| Broken functionality | Test on multiple devices and Android versions |
| Missing privacy policy | Add privacy policy in app and store listing |
| Misleading metadata | Ensure description matches app functionality |
| Intellectual property | Ensure you have rights to all content |

---

## Post-Launch Checklist

### Immediate (Day 1)

- [ ] Verify all API endpoints are working
- [ ] Test user registration and login
- [ ] Test room creation and joining
- [ ] Test voice functionality
- [ ] Monitor error rates in Cloud Monitoring
- [ ] Set up alerts for critical errors

### Week 1

- [ ] Monitor app store reviews and respond
- [ ] Track key metrics:
  - Daily Active Users (DAU)
  - Room creation rate
  - Average session duration
  - Crash-free rate (target: >99%)
- [ ] Address any critical bugs
- [ ] Gather user feedback

### Ongoing

- [ ] Weekly app updates (bug fixes, improvements)
- [ ] Monthly feature releases
- [ ] Regular security audits
- [ ] Database backups (automated)
- [ ] Performance optimization

---

## Monitoring & Maintenance

### GCP Monitoring Setup

```bash
# Enable Cloud Monitoring
gcloud services enable monitoring.googleapis.com

# Create uptime check
gcloud monitoring uptime-check-configs create bolo-debate-api \
  --display-name="Bolo Debate API Health" \
  --http-check=path=/health \
  --monitored-resource=type=cloud_run_revision,labels.service_name=bolo-debate-api
```

### Key Metrics to Monitor

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| API Response Time | <200ms | >500ms |
| Error Rate | <1% | >5% |
| CPU Utilization | <70% | >90% |
| Memory Usage | <80% | >90% |
| Active Users | Growing | -50% drop |

### Alerting Policies

```bash
# Create alert for high error rate
gcloud alpha monitoring policies create \
  --display-name="High Error Rate" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND metric.label.response_code_class="5xx"' \
  --condition-threshold-value=10 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=YOUR_CHANNEL_ID
```

### Backup Strategy

```bash
# Automated daily backups for Cloud SQL
gcloud sql instances patch bolo-debate-db \
  --backup-start-time=02:00 \
  --enable-bin-log

# Backup retention: 7 days (default)
```

---

## Cost Estimation (GCP)

| Service | Estimated Monthly Cost |
|---------|----------------------|
| Cloud Run (1 instance, 512MB) | $15-30 |
| Cloud SQL (db-f1-micro) | $10-15 |
| Cloud Storage (10GB) | $1-2 |
| Cloud CDN | $5-10 |
| **Total** | **$31-57/month** |

*Costs can be higher with increased traffic. Use GCP Pricing Calculator for accurate estimates.*

---

## Support & Resources

- **GCP Documentation:** https://cloud.google.com/docs
- **Flutter Documentation:** https://docs.flutter.dev
- **App Store Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Google Play Policies:** https://play.google.com/console/about/guides/
- **LiveKit Documentation:** https://docs.livekit.io

---

## Quick Reference Commands

```bash
# Deploy backend to Cloud Run
cd backend && gcloud builds submit --config=cloudbuild.yaml

# Build and deploy web
cd apps/flutter_app
flutter build web --release --dart-define=API_BASE_URL=https://YOUR_API_URL
firebase deploy --only hosting

# Build iOS
flutter build ipa --release --dart-define=API_BASE_URL=https://YOUR_API_URL

# Build Android
flutter build appbundle --release --dart-define=API_BASE_URL=https://YOUR_API_URL

# View Cloud Run logs
gcloud run services logs read bolo-debate-api --region=asia-south1

# Connect to database
gcloud sql connect bolo-debate-db --user=postgres
```

---

*Last updated: February 2026*
*Version: 1.0.0*
