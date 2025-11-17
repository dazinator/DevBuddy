#!/bin/bash
# Docker entrypoint script for Headless IDE MCP
# Handles HTTPS certificate setup at runtime with support for:
# 1. Using local dev cert from host (mounted at /https-host)
# 2. Using existing cert from volume (persisted from previous run)
# 3. Generating new cert and persisting to volume

set -e

CERT_PATH="/https/aspnetapp.pfx"
HOST_CERT_PATH="/https-host/aspnetapp.pfx"
CERT_PASSWORD="${ASPNETCORE_Kestrel__Certificates__Default__Password:-DevCertPassword}"

echo "=== Headless IDE MCP - HTTPS Certificate Setup ==="

# Check if local dev cert from host is mounted
if [ -f "$HOST_CERT_PATH" ]; then
    echo "✓ Found local dev cert from host machine at $HOST_CERT_PATH"
    echo "  Copying to container..."
    cp "$HOST_CERT_PATH" "$CERT_PATH"
    chmod 644 "$CERT_PATH"
    echo "  ✓ Using local dev cert from host"
# Check if cert already exists in volume (from previous run)
elif [ -f "$CERT_PATH" ]; then
    echo "✓ Found existing certificate in volume at $CERT_PATH"
    echo "  ✓ Using persisted certificate from previous run"
# Generate new certificate if none exists
else
    echo "○ No existing certificate found"
    echo "  Generating new self-signed development certificate..."
    
    # Clean any existing dev certs
    dotnet dev-certs https --clean
    
    # Generate new certificate
    dotnet dev-certs https -ep "$CERT_PATH" -p "$CERT_PASSWORD" --trust
    
    # Set appropriate permissions
    chmod 644 "$CERT_PATH"
    
    echo "  ✓ New certificate generated and saved to $CERT_PATH"
    echo "  ℹ Certificate will persist across container restarts via Docker volume"
fi

echo "=== Certificate Setup Complete ==="
echo "Certificate location: $CERT_PATH"
echo "Starting application..."
echo ""

# Execute the main application
exec dotnet HeadlessIdeMcp.Server.dll
