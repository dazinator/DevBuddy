# headless-ide-mcp Design Document

## Overview
headless-ide-mcp is a custom Model Context Protocol (MCP) server that provides high-level, .NET-specific code intelligence, solution understanding, DI graph analysis, project navigation, and workflow-support tooling for AI agents. It is designed to operate alongside:

1. A Language Server Protocol (LSP) server such as OmniSharp.
2. An MCPâ€“LSP bridge such as lsp-mcp.
3. A Git-synced workspace containing the current repo.

The MCP server is intentionally decoupled from any workflow engine or orchestration system so that it can be reused by other tools, agents, or automation platforms.

## Architectural Principles

### Small, Composable Tools
Expose minimal, predictable MCP tools. The LLM orchestrates multi-step interactions.

### High-Level Semantics
Low-level code navigation is handled by LSP through lsp-mcp. headless-ide-mcp focuses on higher-level project intelligence such as:

- Solution graph analysis.
- Project dependency mapping.
- DI container graph extraction.
- Work item-to-code mapping utilities.
- Task breakdown support.
- Coding policy analysis.

### Stateless, Pure Server
Tools operate on the repo given via volume mount or via input parameters.

## High-Level Architecture

- git-sync: maintains a local copy of the repository.
- lsp-server: OmniSharp LSP for semantic code navigation.
- lsp-mcp: MCP interface to LSP functions.
- headless-ide-mcp: custom MCP server providing project-aware tools.

## MCP Tools Provided by headless-ide-mcp

### Project Graph Tools
- dotnet.listProjects
- dotnet.getProjectInfo
- dotnet.fileToProject
- dotnet.getDependencies

### DI Graph Tools
- dotnet.scanDiGraph
- dotnet.findImplementations(interfaceName)

### Work Item Context Tools
- ado.getWorkItemContext(id)
- ado.linkedCommits(id)

### Code Impact Heuristics
- dotnet.suggestRelevantFiles(workItemText)
- dotnet.proposeTaskBreakdown(files, context)

### Policy Tools
- policy.validateCodingRules(path)
- policy.evaluateRefactorImpact(files)

## MCP Tools Provided by lsp-mcp
- lsp.search
- lsp.readFile
- lsp.findSymbol
- lsp.findReferences
- lsp.listSymbolsInFile
- lsp.getDocumentDiagnostics

## Repository Sync Strategy

Use git-sync to maintain a local repo at /repo. Mount this directory into lsp-server, lsp-mcp, and optionally headless-ide-mcp.

Alternatively, tools can be designed to accept file content and project structure directly via tool call input.

## Docker Compose Template

version: "3.9"
services:
  git-sync:
    image: k8s.gcr.io/git-sync/git-sync:v4
    volumes:
      - repo:/repo
    environment:
      - GIT_SYNC_REPO=https://github.com/your/repo.git
      - GIT_SYNC_BRANCH=develop
      - GIT_SYNC_ONE_TIME=false
      - GIT_SYNC_ROOT=/repo

  lsp-server:
    image: your/omnisharp-lsp
    volumes:
      - repo:/repo

  lsp-mcp:
    image: your/lsp-mcp
    volumes:
      - repo:/repo

  headless-ide-mcp:
    image: your/headless-ide-mcp
    volumes:
      - repo:/repo

volumes:
  repo:

## Development Roadmap

### Phase 1 â€” Core Setup
- MCP server scaffolding.
- Project graph extraction.
- DI graph scanning.

### Phase 2 â€” LSP Integration
- Ensure lsp-mcp is functioning.
- Add higher-level heuristic tools.

### Phase 3 â€” Enhanced Semantics
- Context-aware file suggestion.
- Policy tools.
- Task breakdown utilities.

### Phase 4 â€” Refinement and Expansion
- Additional language support.
- Custom refactoring helpers.
- Further tooling for architectural analysis.

## Summary

headless-ide-mcp is a modular, reusable MCP server that extends existing LSP capabilities with .NET-specific structural and semantic tools. It focuses exclusively on providing an interface suitable for LLM-based agents, without prescribing any particular workflow engine.
