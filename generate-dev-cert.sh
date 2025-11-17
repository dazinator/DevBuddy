#!/bin/bash
# Script to generate ASP.NET Core development certificate
# This script is used in the Dockerfile to create a self-signed certificate for HTTPS

set -e

echo "=== Generating ASP.NET Core Development Certificate ==="

# Generate the certificate
dotnet dev-certs https --clean
dotnet dev-certs https -ep /https/aspnetapp.pfx -p DevCertPassword --trust

# Set appropriate permissions
chmod 644 /https/aspnetapp.pfx

echo "=== Development certificate generated successfully ==="
echo "Certificate location: /https/aspnetapp.pfx"
echo "Password: DevCertPassword"
