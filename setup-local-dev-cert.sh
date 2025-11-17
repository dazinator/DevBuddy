#!/bin/bash
# Setup script to prepare local development certificate for use with Docker container
# This script helps set up Option 1 from docs/https-setup.md

set -e

echo "=== Local Development Certificate Setup ==="
echo ""
echo "This script will prepare your local .NET development certificate"
echo "for use with the Headless IDE MCP Docker container."
echo ""

# Determine the certificate directory based on OS
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    CERT_DIR="$APPDATA/ASP.NET/Https"
    echo "Detected Windows environment"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CERT_DIR="$HOME/.aspnet/https"
    echo "Detected macOS environment"
else
    # Linux
    CERT_DIR="$HOME/.aspnet/https"
    echo "Detected Linux environment"
fi

CERT_FILE="$CERT_DIR/aspnetapp.pfx"

echo "Certificate directory: $CERT_DIR"
echo ""

# Create the certificate directory if it doesn't exist
if [ ! -d "$CERT_DIR" ]; then
    echo "Creating certificate directory..."
    mkdir -p "$CERT_DIR"
fi

# Check if certificate already exists
if [ -f "$CERT_FILE" ]; then
    echo "✓ Certificate already exists at: $CERT_FILE"
    echo ""
    read -p "Do you want to regenerate it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing certificate."
        echo ""
        echo "Next steps:"
        echo "1. Edit docker-compose.yml and uncomment the local cert volume mount"
        echo "2. Run: docker-compose up --build"
        exit 0
    fi
fi

# Generate the certificate
echo ""
echo "Generating development certificate..."
echo "Password: DevCertPassword (same as used by the container)"
echo ""

dotnet dev-certs https -ep "$CERT_FILE" -p DevCertPassword --trust

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Certificate generated successfully!"
    echo "  Location: $CERT_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Edit docker-compose.yml and uncomment the appropriate volume mount:"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "   - \${APPDATA}/ASP.NET/Https:/https-host:ro"
    else
        echo "   - ~/.aspnet/https:/https-host:ro"
    fi
    echo "2. Run: docker-compose up --build"
    echo ""
    echo "The container will automatically use your local dev certificate!"
else
    echo ""
    echo "✗ Failed to generate certificate"
    echo "Please ensure .NET SDK is installed and try again."
    exit 1
fi
