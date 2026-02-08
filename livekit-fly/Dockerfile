# LiveKit Server for Fly.io
FROM livekit/livekit-server:latest

# Copy config
COPY livekit.yaml /livekit.yaml

# Expose ports
EXPOSE 7880 7881 7882/udp

# Start LiveKit
CMD ["--config", "/livekit.yaml"]
