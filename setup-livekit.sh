#!/bin/bash

# LiveKit Self-Hosted Setup Script for macOS
# LiveKit is free and open source - https://livekit.io

set -e

echo "🎙️  Setting up self-hosted LiveKit server..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    LIVEKIT_ARCH="amd64"
elif [ "$ARCH" = "arm64" ]; then
    LIVEKIT_ARCH="arm64"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

LIVEKIT_VERSION="1.7.2"
LIVEKIT_DIR="$(pwd)/livekit"

echo "📁 Creating LiveKit directory..."
mkdir -p "$LIVEKIT_DIR"
cd "$LIVEKIT_DIR"

# Download LiveKit server
DOWNLOAD_URL="https://github.com/livekit/livekit/releases/download/v${LIVEKIT_VERSION}/livekit_${LIVEKIT_VERSION}_darwin_${LIVEKIT_ARCH}.tar.gz"
echo "📥 Downloading LiveKit v${LIVEKIT_VERSION} for darwin/${LIVEKIT_ARCH}..."
curl -sSL "$DOWNLOAD_URL" -o livekit.tar.gz

echo "📦 Extracting..."
tar -xzf livekit.tar.gz
rm livekit.tar.gz
chmod +x livekit-server

# Create config file
echo "⚙️  Creating configuration..."
cat > livekit.yaml << 'EOF'
# LiveKit Server Configuration
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: false

keys:
  devkey: secret

room:
  auto_create: true
  enabled_codecs:
    - mime: audio/opus
    - mime: video/VP8
    - mime: video/H264

logging:
  level: info
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting LiveKit server on ws://localhost:7880..."
./livekit-server --config livekit.yaml --dev
EOF
chmod +x start.sh

echo ""
echo "✅ LiveKit setup complete!"
echo ""
echo "📍 Location: $LIVEKIT_DIR"
echo ""
echo "To start LiveKit server, run:"
echo "  cd livekit && ./start.sh"
echo ""
echo "LiveKit will be available at: ws://localhost:7880"
echo "API Key: devkey"
echo "API Secret: secret"
echo ""
