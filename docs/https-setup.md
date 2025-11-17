# HTTPS Configuration

The Headless IDE MCP server supports HTTPS using a development certificate that is automatically generated when the container starts.

## Overview

The container is configured with:
- **HTTP** on port 8080 (mapped to host port 5000)
- **HTTPS** on port 8081 (mapped to host port 5001)
- A self-signed development certificate generated at container build time

## Using HTTPS

When running the container with docker-compose, HTTPS is automatically configured and available:

```bash
docker-compose up --build
```

The server will be available at:
- **HTTP**: `http://localhost:5000`
- **HTTPS**: `https://localhost:5001`

## Testing HTTPS Connection

You can test the HTTPS endpoint with curl:

```bash
# Use --insecure (-k) flag because the certificate is self-signed
curl https://localhost:5001/health --insecure
```

Expected response:
```json
{"status":"healthy","codeBasePath":"/workspace"}
```

## Certificate Details

The development certificate is:
- **Location**: `/https/aspnetapp.pfx` (inside the container)
- **Password**: `DevCertPassword`
- **Type**: Self-signed development certificate
- **Generated**: Automatically during container build using `dotnet dev-certs https`

## Trusting the Certificate Locally

Since the certificate is self-signed, browsers and tools will show security warnings. For development purposes, you can:

### Option 1: Use the --insecure Flag (Recommended for Testing)

When using curl or similar tools:
```bash
curl https://localhost:5001/health --insecure
```

### Option 2: Export and Trust the Certificate (Advanced)

If you need to trust the certificate system-wide:

1. **Export the certificate from the running container:**
   ```bash
   docker cp headless-ide-mcp-server:/https/aspnetapp.pfx ./aspnetapp.pfx
   ```

2. **Import the certificate to your system:**

   **Windows:**
   ```powershell
   # Import to user's certificate store
   certutil -user -p DevCertPassword -importpfx aspnetapp.pfx
   ```

   **macOS:**
   ```bash
   # Convert PFX to PEM format
   openssl pkcs12 -in aspnetapp.pfx -out aspnetapp.pem -nodes -password pass:DevCertPassword
   
   # Add to keychain and trust
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain aspnetapp.pem
   ```

   **Linux (Ubuntu/Debian):**
   ```bash
   # Convert PFX to CRT format
   openssl pkcs12 -in aspnetapp.pfx -clcerts -nokeys -out aspnetapp.crt -password pass:DevCertPassword
   
   # Copy to system certificates
   sudo cp aspnetapp.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   ```

3. **Restart your browser or application** to recognize the newly trusted certificate.

**⚠️ Security Note**: Only trust development certificates on development machines. Never use development certificates in production environments.

## Using with Claude Desktop

Claude Desktop's remote connector requires HTTPS. With this configuration, you can now use:

```json
{
  "mcpServers": {
    "headless-ide": {
      "url": "https://localhost:5001/",
      "allowSelfSignedCerts": true
    }
  }
}
```

**Note**: Check Claude Desktop's documentation for the exact configuration format, as support for `allowSelfSignedCerts` may vary by version.

## Production Deployment

For production deployments, you should:

1. **Replace the development certificate** with a proper certificate from a Certificate Authority (CA)
2. **Use environment variables** to configure the certificate path and password:
   ```yaml
   environment:
     - ASPNETCORE_Kestrel__Certificates__Default__Path=/path/to/your/cert.pfx
     - ASPNETCORE_Kestrel__Certificates__Default__Password=YourSecurePassword
   ```
3. **Mount the certificate** as a volume:
   ```yaml
   volumes:
     - /path/to/certs:/https:ro
   ```
4. **Use secrets management** for the certificate password instead of environment variables

## Troubleshooting

### Certificate Not Found Error

If you see an error about the certificate not being found:

1. **Verify the certificate was generated:**
   ```bash
   docker exec headless-ide-mcp-server ls -la /https/
   ```
   You should see `aspnetapp.pfx`

2. **Check the logs:**
   ```bash
   docker-compose logs headless-ide-mcp
   ```
   Look for messages about certificate generation

3. **Rebuild the container:**
   ```bash
   docker-compose down
   docker-compose up --build
   ```

### HTTPS Not Working

1. **Verify the HTTPS port is exposed:**
   ```bash
   docker ps
   ```
   Look for `0.0.0.0:5001->8081/tcp`

2. **Check if the port is listening:**
   ```bash
   curl https://localhost:5001/health --insecure
   ```

3. **Review container logs:**
   ```bash
   docker-compose logs -f headless-ide-mcp
   ```

### Browser Security Warnings

This is expected with self-signed certificates. Options:
- Use the `--insecure` flag with curl/tools
- Trust the certificate locally (see above)
- Use a proper CA-signed certificate for production

## Technical Details

### Certificate Generation

The certificate is generated using the `dotnet dev-certs https` command in the Dockerfile:

```bash
dotnet dev-certs https --clean
dotnet dev-certs https -ep /https/aspnetapp.pfx -p DevCertPassword --trust
```

### Kestrel Configuration

The application is configured to listen on both HTTP and HTTPS ports in `Program.cs`:

```csharp
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.ListenAnyIP(8080); // HTTP
    serverOptions.ListenAnyIP(8081, listenOptions =>
    {
        listenOptions.UseHttps(); // HTTPS
    });
});
```

The certificate path and password are configured via environment variables:
- `ASPNETCORE_Kestrel__Certificates__Default__Path`
- `ASPNETCORE_Kestrel__Certificates__Default__Password`

## Related Documentation

- [Getting Started Guide](getting-started.md)
- [Claude Desktop Setup](claude-desktop-setup.md)
- [Security Documentation](security.md)
- [Operations Guide](operations.md)
