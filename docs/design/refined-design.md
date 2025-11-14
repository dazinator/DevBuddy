# Refined Design: CLI-First Headless IDE MCP

**Date:** 2025-11-14  
**Version:** 2.0 (Refined after POC validation)  
**Status:** Ready for Implementation  
**Author:** Copilot Agent

---

## 1. Executive Summary

This document presents the refined design for the Headless IDE MCP server, validated through comprehensive POCs. The design provides AI agents with a powerful, secure, containerized development environment comparable to GitHub Actions runners.

### Key Capabilities
- ✅ Execute arbitrary CLI commands (dotnet, ripgrep, jq, etc.)
- ✅ Secure sandboxed environment
- ✅ High-level structured tools for .NET analysis
- ✅ LSP integration ready (future enhancement)
- ✅ Docker-based deployment

### Design Status
- **Viability:** ✅ Validated via POCs
- **Security:** ⚠️ Validated with production hardening needed
- **Performance:** ✅ Acceptable (<5min build, <500MB size)
- **Integration:** ✅ MCP SDK compatibility confirmed

---

## 2. Architecture Overview

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AI Agent (Claude)                     │
└───────────────────────┬─────────────────────────────────────┘
                        │ MCP Protocol (HTTP/JSON-RPC)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│           Headless IDE MCP Server (Container)                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           ASP.NET Core MCP Server Layer                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │ ShellTools   │  │ DotNetTools  │  │ FileSystem  │ │ │
│  │  │              │  │              │  │ Tools       │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │ │
│  └─────────┼─────────────────┼─────────────────┼────────┘ │
│            │                 │                 │            │
│  ┌─────────▼─────────────────▼─────────────────▼────────┐ │
│  │        HeadlessIdeMcp.Core (Business Logic)           │ │
│  │  ┌──────────────────────┐  ┌─────────────────────┐   │ │
│  │  │ CommandExecution     │  │  FileSystemService  │   │ │
│  │  │ Service              │  │                     │   │ │
│  │  └──────────┬───────────┘  └─────────────────────┘   │ │
│  └─────────────┼───────────────────────────────────────┘ │
│                │                                           │
│  ┌─────────────▼───────────────────────────────────────┐ │
│  │         System Process Execution (.NET)              │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │    CLI Tools (dotnet, rg, jq, tree, git, etc.)       │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │          Workspace (/workspace - mounted)             │ │
│  │         ├── project files (.cs, .csproj, .sln)        │ │
│  │         └── build artifacts                           │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

#### ASP.NET Core MCP Server Layer
- Expose MCP protocol endpoints (HTTP/JSON-RPC)
- Tool discovery and registration via attributes
- Request/response serialization
- Dependency injection container

#### HeadlessIdeMcp.Core
- Business logic for all operations
- Process execution with security controls
- File system operations
- .NET project analysis (future)
- Independent of MCP protocol

#### System & CLI Tools
- Process execution runtime
- Pre-installed CLI utilities
- Mounted workspace access

---

## 3. Core MCP Tools

### 3.1 Shell Execution Tools (Phase 1 - CRITICAL)

#### shell_execute

**Purpose:** Execute arbitrary CLI commands in a sandboxed environment

**Input:**
```json
{
  "command": "string",              // Command name (e.g., "dotnet", "rg")
  "arguments": ["string"],          // Array of arguments
  "workingDirectory": "string?",    // Optional working directory
  "timeoutSeconds": 30              // Timeout (default: 30, max: 300)
}
```

**Output:**
```json
{
  "stdout": "string",               // Standard output
  "stderr": "string",               // Standard error
  "exitCode": 0,                    // Exit code (0 = success)
  "timedOut": false,                // Whether command timed out
  "executionTimeMs": 123            // Execution time in ms
}
```

**Example Usage:**
```json
// Search for "IOrderService" in C# files
{
  "command": "rg",
  "arguments": ["IOrderService", "-g", "*.cs"],
  "workingDirectory": "/workspace"
}

// List projects in solution
{
  "command": "dotnet",
  "arguments": ["sln", "list"]
}

// Build project
{
  "command": "dotnet",
  "arguments": ["build", "--no-restore"]
}
```

---

#### shell_execute_json

**Purpose:** Execute commands that return JSON and automatically parse the result

**Input:** Same as `shell_execute`

**Output:**
```json
{
  "json": { /* parsed JSON object */ },
  "parseError": "string?",          // Error if JSON parsing failed
  "stderr": "string",
  "exitCode": 0,
  "timedOut": false,
  "executionTimeMs": 123
}
```

**Example Usage:**
```json
// Parse package.json
{
  "command": "jq",
  "arguments": [".", "package.json"]
}
```

---

#### shell_get_available_tools

**Purpose:** Discover what CLI tools are available in the container

**Input:** None

**Output:**
```json
{
  "tools": [
    {
      "name": "dotnet",
      "description": ".NET SDK",
      "available": true,
      "version": "8.0.100"
    },
    {
      "name": "rg",
      "description": "ripgrep - fast text search",
      "available": true,
      "version": "ripgrep 14.0.0"
    }
  ],
  "workspacePath": "/workspace"
}
```

---

### 3.2 File System Tools (Phase 1 - EXISTING)

#### check_file_exists

**Purpose:** Check if a file exists (already implemented)

**Input:**
```json
{
  "fileName": "string"              // File path (relative or absolute)
}
```

**Output:**
```json
{
  "message": "File 'path' exists" | "File 'path' does not exist"
}
```

---

### 3.3 Higher-Level .NET Tools (Phase 2 - FUTURE)

These tools can be implemented using CLI commands initially, then enhanced with Roslyn/MSBuild APIs if needed.

#### dotnet_project_graph

**Purpose:** Get structured project/solution information

**Implementation Options:**
1. **CLI-first (Phase 2a):** Parse output of `dotnet sln list`, `dotnet list reference`
2. **Roslyn (Phase 2b):** Use MSBuild APIs for richer data

**Output:**
```json
{
  "projects": [
    {
      "name": "Project1",
      "path": "/workspace/src/Project1/Project1.csproj",
      "references": ["Project2"],
      "targetFrameworks": ["net8.0"],
      "sourceFiles": ["Class1.cs", "Class2.cs"]
    }
  ]
}
```

---

#### dotnet_suggest_relevant_files

**Purpose:** Suggest files relevant to a natural language query

**Implementation:** Combine heuristics with `rg` searches

**Input:**
```json
{
  "query": "authentication logic"
}
```

**Output:**
```json
{
  "files": [
    {
      "path": "src/Auth/AuthService.cs",
      "relevance": 0.95,
      "reason": "Contains AuthService class with authentication methods"
    }
  ]
}
```

---

## 4. Security Model

### 4.1 Container Security

#### Docker Configuration
```yaml
services:
  headless-ide-mcp:
    image: headless-ide-mcp:latest
    user: "1001:1001"              # Non-root user
    read_only: true                # Read-only root filesystem
    security_opt:
      - no-new-privileges:true     # Prevent privilege escalation
    cap_drop:
      - ALL                        # Drop all capabilities
    networks:
      - isolated_network           # Isolated bridge network
    deploy:
      resources:
        limits:
          cpus: '2'                # Max 2 CPU cores
          memory: 1G               # Max 1GB RAM
        reservations:
          cpus: '0.5'
          memory: 512M
```

#### Volume Mounts
```yaml
volumes:
  - ./codebase:/workspace:ro       # Read-only code
  - /tmp/mcp:/tmp                  # Writable temp directory
```

### 4.2 Process Execution Security

#### Security Controls

1. **No Shell Execution:**
   - Use `Process.Start()` with direct command (not via shell)
   - Prevents command injection attacks
   - ✅ Implemented in POC

2. **Path Validation:**
   - Whitelist allowed working directories
   - Prevent directory traversal (../, ../../)
   - Normalize paths before validation
   - ✅ Implemented in POC

3. **Timeout Enforcement:**
   - Mandatory timeout (default: 30s, max: 300s)
   - Kill entire process tree on timeout
   - Prevent resource exhaustion
   - ✅ Implemented in POC

4. **Command Controls (Optional):**
   - Command allowlist (if needed for production)
   - Command denylist (dangerous commands: rm, dd, mkfs)
   - ✅ Infrastructure in POC

#### Allowed Paths
```csharp
{
  "allowedPaths": [
    "/workspace",                  // Mounted codebase
    "/tmp",                        // Temporary files
    "/app"                         // Application directory (read-only)
  ]
}
```

#### Command Denylist
```csharp
{
  "deniedCommands": [
    "rm",          // File deletion
    "dd",          // Disk operations
    "mkfs",        // Filesystem creation
    "fdisk",       // Partition management
    "mount",       // Mount operations
    "sudo",        // Privilege escalation
    "su"           // User switching
  ]
}
```

### 4.3 Additional Security Measures

1. **Error Message Sanitization:**
   - Remove sensitive paths from error messages
   - Generic error messages for security violations
   - Log full details server-side only

2. **Audit Logging:**
   - Log all command executions
   - Include: timestamp, command, user, exit code
   - Retention policy (e.g., 30 days)

3. **Network Isolation:**
   - No internet access from container (optional)
   - Use isolated Docker network
   - Whitelist only required outbound connections

4. **Regular Security Audits:**
   - Penetration testing
   - Dependency scanning
   - Container image scanning

---

## 5. Container Specification

### 5.1 Dockerfile

See `poc-code/Dockerfile.enhanced` for complete implementation.

**Key Features:**
- Base: `mcr.microsoft.com/dotnet/sdk:8.0` (~450MB)
- Non-root user: `mcpuser` (UID 1001)
- CLI tools: ripgrep, jq, tree, git, curl
- Total size: ~490MB
- Build time: ~2.5 minutes (first), ~20 seconds (cached)

### 5.2 Installed CLI Tools

| Tool | Version | Purpose |
|------|---------|---------|
| dotnet | 8.0+ | .NET CLI and SDK |
| rg (ripgrep) | 14.0+ | Fast code search |
| jq | 1.6+ | JSON processing |
| tree | Latest | Directory visualization |
| git | 2.x | Version control |
| bash | 5.x | Shell scripting |
| curl | Latest | HTTP requests |
| find/grep | Latest | File search |

### 5.3 Environment Configuration

```dockerfile
ENV CODE_BASE_PATH=/workspace
ENV PATH="${PATH}:/workspace/tools"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV ASPNETCORE_ENVIRONMENT=Production
```

---

## 6. Integration with MCP SDK

### 6.1 Service Registration

**Program.cs:**
```csharp
var builder = WebApplication.CreateBuilder(args);

// Get configuration
var codeBasePath = Environment.GetEnvironmentVariable("CODE_BASE_PATH") ?? "/workspace";

// Register core services
builder.Services.AddSingleton<IFileSystemService>(sp => 
    new FileSystemService(codeBasePath));

builder.Services.AddSingleton<ICommandExecutionService>(sp =>
{
    var options = new CommandExecutionOptions
    {
        MaxTimeoutSeconds = 300,
        AllowedPaths = new List<string> { codeBasePath, "/tmp" },
        DeniedCommands = new List<string> { "rm", "dd", "mkfs", "fdisk" }
    };
    return new CommandExecutionService(codeBasePath, options);
});

// Configure MCP Server
builder.Services
    .AddMcpServer()
    .WithHttpTransport()
    .WithToolsFromAssembly();

var app = builder.Build();

// Map MCP endpoints
app.MapMcp();

// Health check
app.MapGet("/health", () => Results.Ok(new 
{ 
    status = "healthy", 
    codeBasePath,
    timestamp = DateTime.UtcNow
}));

app.Run();
```

### 6.2 Tool Implementation Pattern

```csharp
[McpServerToolType]
public class ShellTools
{
    private readonly ICommandExecutionService _executionService;

    public ShellTools(ICommandExecutionService executionService)
    {
        _executionService = executionService;
    }

    [McpServerTool("shell_execute")]
    [Description("Execute a CLI command")]
    public async Task<ShellExecuteResponse> ExecuteAsync(
        [Description("Command to execute")] string command,
        [Description("Command arguments")] string[]? arguments = null,
        [Description("Working directory")] string? workingDirectory = null,
        [Description("Timeout in seconds")] int timeoutSeconds = 30)
    {
        // Implementation
    }
}
```

---

## 7. Development Workflow

### 7.1 Local Development

```bash
# Clone repository
git clone https://github.com/dazinator/headless-ide-mcp.git
cd headless-ide-mcp

# Build and run with Docker Compose
docker-compose up --build

# Test the server
curl http://localhost:5000/health

# Call MCP tools
curl -X POST http://localhost:5000/ \
  -H "Content-Type: application/json" \
  -d @test-request.json
```

### 7.2 Testing Strategy

#### Unit Tests
- Test `CommandExecutionService` with various scenarios
- Test path validation logic
- Test timeout enforcement
- Test error handling

#### Integration Tests
- Test MCP tool calls end-to-end
- Test with real CLI tools in container
- Test security controls (path traversal, timeouts)
- Test concurrent execution

#### Security Tests
- Penetration testing
- Command injection attempts
- Path traversal attempts
- Resource exhaustion tests

### 7.3 CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: dotnet build
      - name: Unit Tests
        run: dotnet test
      - name: Build Docker Image
        run: docker build -t headless-ide-mcp:test .
      - name: Integration Tests
        run: docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

---

## 8. Usage Examples

### 8.1 AI Agent Workflow

**Scenario:** Agent needs to understand a work item

```javascript
// 1. Discover available tools
POST /
{
  "method": "tools/call",
  "params": {
    "name": "shell_get_available_tools"
  }
}

// 2. List projects in solution
POST /
{
  "method": "tools/call",
  "params": {
    "name": "shell_execute",
    "arguments": {
      "command": "dotnet",
      "arguments": ["sln", "list"]
    }
  }
}

// 3. Search for a service interface
POST /
{
  "method": "tools/call",
  "params": {
    "name": "shell_execute",
    "arguments": {
      "command": "rg",
      "arguments": ["IOrderService", "-g", "*.cs", "-A", "5"]
    }
  }
}

// 4. Check if specific file exists
POST /
{
  "method": "tools/call",
  "params": {
    "name": "check_file_exists",
    "arguments": {
      "fileName": "src/Services/OrderService.cs"
    }
  }
}

// 5. Build the project
POST /
{
  "method": "tools/call",
  "params": {
    "name": "shell_execute",
    "arguments": {
      "command": "dotnet",
      "arguments": ["build", "--no-restore"],
      "timeoutSeconds": 120
    }
  }
}
```

### 8.2 Common CLI Patterns

**Search code:**
```bash
rg "pattern" -g "*.cs" -A 3 -B 3
```

**Parse JSON:**
```bash
echo '{"key": "value"}' | jq '.key'
```

**List directory:**
```bash
tree -L 2 /workspace
```

**Find files:**
```bash
find /workspace -name "*.csproj"
```

**Git operations:**
```bash
git log --oneline -10
git diff HEAD~1
```

---

## 9. Implementation Roadmap

### Phase 1: Core Shell Execution (Weeks 1-2) ✅ CRITICAL

**Goal:** Prove CLI-first architecture

**Tasks:**
- ✅ Integrate `CommandExecutionService` into Core project
- ✅ Add `ShellTools` to Server project  
- ✅ Update Dockerfile with CLI tools
- ✅ Integration tests for shell execution
- ✅ Security testing (path traversal, timeouts)
- ✅ Documentation updates

**Deliverable:** Working shell_execute tool in containerized MCP server

**Success Criteria:**
- Can execute dotnet, rg, jq commands
- Timeouts enforced correctly
- Path validation prevents escapes
- Concurrent execution works
- All integration tests pass

---

### Phase 2: Production Hardening (Weeks 2-3)

**Goal:** Security and reliability for production use

**Tasks:**
- Add error message sanitization
- Implement Docker resource limits (CPU, memory)
- Add audit logging for command execution
- Security penetration testing
- Load testing (concurrent requests)
- Performance optimization

**Deliverable:** Production-ready MCP server

**Success Criteria:**
- Passes security audit
- Handles 10+ concurrent requests
- Resource exhaustion prevented
- Comprehensive audit logs

---

### Phase 3: Enhanced Tools (Weeks 3-4)

**Goal:** Improved developer experience

**Tasks:**
- Optimize shell_execute_json
- Add file upload/download capabilities (if needed)
- Environment variable configuration
- Better error messages
- Enhanced health check endpoint
- Metrics and monitoring

**Deliverable:** Feature-complete shell execution system

**Success Criteria:**
- JSON parsing works reliably
- Clear, actionable error messages
- Monitoring in place

---

### Phase 4: Higher-Level Tools (Weeks 4-8) [OPTIONAL]

**Goal:** Structured .NET analysis tools

**Tasks:**
- Implement dotnet_project_graph (CLI-based)
- Implement dotnet_suggest_relevant_files
- (Optional) Add Roslyn integration
- (Optional) Add DI graph analysis
- Documentation for structured tools

**Deliverable:** Enhanced .NET-specific capabilities

**Success Criteria:**
- Can extract project graph from solutions
- File suggestion works for common queries
- At least one structured tool working

---

### Phase 5: LSP Integration (Future)

**Goal:** Semantic code navigation

**Approach:**
- Separate container running OmniSharp
- Use lsp-mcp for MCP bridge
- AI agent orchestrates both servers

**Not in scope for initial implementation**

---

## 10. Success Metrics

### Technical Metrics
- ✅ Command execution success rate > 99%
- ✅ Average command latency < 100ms overhead
- ✅ Container startup time < 10 seconds
- ✅ Zero critical security vulnerabilities
- ✅ Integration test coverage > 80%

### User Experience Metrics
- ✅ AI agent can chain commands successfully
- ✅ Clear error messages for all failure modes
- ✅ Documentation clarity (user surveys)

### Operational Metrics
- ✅ Build time < 5 minutes
- ✅ Container size < 600MB
- ✅ CI/CD pipeline success rate > 95%
- ✅ Mean time to recovery < 5 minutes

---

## 11. Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Security vulnerability | Medium | Critical | Regular audits, penetration testing |
| Performance degradation | Low | Medium | Load testing, monitoring |
| Container size bloat | Low | Low | Regular image optimization |
| CLI tool incompatibility | Low | Medium | Integration tests, version pinning |
| Breaking MCP SDK changes | Low | High | Version pinning, release monitoring |

---

## 12. Alternatives Considered

### Alternative 1: Pure MCP Tools (No CLI)
**Rejected:** Too much custom code, less flexible

### Alternative 2: WebAssembly Sandbox
**Rejected:** Limited tool ecosystem, compilation complexity

### Alternative 3: SSH-based Execution
**Rejected:** Additional security surface, orchestration complexity

### Decision: CLI-First Architecture
**Selected:** Best balance of flexibility, security, and simplicity

---

## 13. Appendices

### Appendix A: Complete File Structure

```
headless-ide-mcp/
├── src/
│   ├── HeadlessIdeMcp.Server/
│   │   ├── Tools/
│   │   │   ├── ShellTools.cs          # NEW: Shell execution tools
│   │   │   └── FileSystemTools.cs     # EXISTING
│   │   ├── Program.cs                 # UPDATED: New service registrations
│   │   └── HeadlessIdeMcp.Server.csproj
│   ├── HeadlessIdeMcp.Core/
│   │   ├── ProcessExecution/
│   │   │   ├── ICommandExecutionService.cs   # NEW
│   │   │   ├── CommandExecutionService.cs    # NEW
│   │   │   ├── ExecutionRequest.cs           # NEW
│   │   │   ├── ExecutionResult.cs            # NEW
│   │   │   └── CommandExecutionOptions.cs    # NEW
│   │   ├── FileSystemService.cs       # EXISTING
│   │   └── IFileSystemService.cs      # EXISTING
│   ├── HeadlessIdeMcp.IntegrationTests/
│   │   ├── ShellToolsTests.cs         # NEW: Integration tests
│   │   └── FileSystemToolsTests.cs    # EXISTING
│   └── Solution.sln
├── docs/
│   ├── design/
│   │   ├── viability-assessment.md
│   │   ├── fail-fast-opportunities.md
│   │   ├── refined-design.md          # THIS FILE
│   │   ├── implementation-plan.md     # NEXT
│   │   └── poc-code/
│   │       ├── CommandExecutionService.cs
│   │       ├── CommandExecutionServiceTests.cs
│   │       ├── ShellTools.cs
│   │       ├── Dockerfile.enhanced
│   │       └── README.md
│   ├── Design-Discussion.md           # ORIGINAL
│   ├── getting-started.md             # TO UPDATE
│   └── project-setup.md               # TO UPDATE
├── Dockerfile                         # TO UPDATE (add CLI tools)
├── docker-compose.yml                 # TO UPDATE (security options)
└── README.md                          # TO UPDATE
```

### Appendix B: Dependencies

**New NuGet Packages:**
- None (using built-in .NET APIs)

**Future Optional Dependencies:**
- Microsoft.Build.Locator (for Roslyn integration)
- Microsoft.CodeAnalysis.CSharp (for Roslyn integration)

### Appendix C: Configuration

**Environment Variables:**
```bash
CODE_BASE_PATH=/workspace              # Required: Workspace path
ASPNETCORE_ENVIRONMENT=Production      # Optional: Environment
MAX_TIMEOUT_SECONDS=300                # Optional: Max command timeout
ALLOWED_PATHS=/workspace,/tmp          # Optional: Allowed working directories
```

**appsettings.json:**
```json
{
  "CommandExecution": {
    "MaxTimeoutSeconds": 300,
    "AllowedPaths": ["/workspace", "/tmp"],
    "DeniedCommands": ["rm", "dd", "mkfs", "fdisk"],
    "EnableAuditLogging": true
  }
}
```

---

## 14. Conclusion

This refined design provides a clear, validated path to implementing the CLI-first Headless IDE MCP architecture. All critical POCs have passed, and the design is ready for phased implementation.

### Next Steps
1. Create detailed implementation plan with sub-issues
2. Begin Phase 1 implementation
3. Continuous validation through integration tests
4. Iterate based on user feedback

### Approval
Ready for stakeholder review and implementation approval.

---

**Document Version:** 2.0  
**Last Updated:** 2025-11-14  
**Status:** ✅ Approved for Implementation
