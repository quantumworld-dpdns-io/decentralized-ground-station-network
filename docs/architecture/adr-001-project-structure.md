# ADR-001: Multi-Language Monorepo Structure

## Status

Accepted

## Context

The Decentralized Ground Station Network requires:
1. High-performance cryptographic operations (Rust with PQC)
2. Enterprise-grade API server (Go with gRPC)
3. Quantum computing integration (Python with Qiskit)
4. Real-time signal processing (Julia with DSP.jl)
5. Modern web interface (TypeScript/Next.js)
6. Efficient data serialization (Protocol Buffers)

Each language is chosen for its strengths in a specific domain. A monorepo structure enables coordinated development across these languages.

## Decision

We adopt a monorepo structure with the following organization:

```
/
├── .github/           # CI/CD workflows
├── configs/           # Service configuration files
├── deployments/       # Docker, Kubernetes, Terraform
├── docs/              # Architecture, API, quantum docs
├── scripts/           # Build, test, deploy scripts
├── src/
│   ├── backend/       # Go gRPC server
│   ├── crypto-kernel/ # Rust PQC library
│   ├── frontend/      # Next.js web UI
│   ├── proto/         # Protobuf definitions
│   ├── quantum-circuits/  # OpenQASM 3.0 circuits
│   ├── quantum-engine/    # Python quantum framework
│   └── signal-processing/ # Julia DSP library
└── tests/             # E2E and integration tests
```

### Key Principles

1. **Language-Specific Builds**: Each language directory contains its own build system (go.mod, Cargo.toml, pyproject.toml, Project.toml, package.json)
2. **Shared Protobufs**: All service interfaces defined in `src/proto/` and compiled per-language
3. **Unified Makefile**: Top-level Makefile delegates to language-specific tooling
4. **Docker Compose**: Full-stack composition for local development
5. **Consistent Versioning**: All components share the same version tag

### Communication Patterns

- **Inter-Service**: gRPC with protobuf serialization
- **Intra-Service**: C FFI (Go -> Rust crypto), HTTP/gRPC (others)
- **Async**: Redis pub/sub for event distribution
- **Data Exchange**: Apache Arrow for large datasets

### Dependency Management

- Go backend imports generated gRPC/protobuf code via `go.mod`
- Rust crypto kernel uses `liboqs-sys` for PQC algorithms
- Python quantum engine uses `qiskit`, `cuda-quantum` optionally
- Julia signal processing uses `DSP.jl`, `FFTW.jl`, `Optim.jl`

## Consequences

### Positive
- Single source of truth for API definitions (protobuf)
- Coordinated versioning across all components
- Simplified CI/CD with unified workflows
- Shared configuration and deployment templates

### Negative
- Larger repository size (all languages, all tools)
- Requires toolchain for all languages during development
- Potential for conflicting dependency trees

### Mitigations
- Docker containers isolate language environments
- CI only builds changed components where possible
- Pre-commit hooks enforce code quality per language
- `.gitignore` excludes build artifacts from all languages

## Related Decisions

- ADR-002: Post-Quantum Cryptography Algorithm Selection
- ADR-003: Quantum Computing Integration Strategy
- ADR-004: Signal Processing Pipeline Architecture

## References

- [Monorepo Patterns in Google](https://research.google/pubs/pub45424/)
- [Protobuf Best Practices](https://protobuf.dev/programming-guides/dos-donts/)
- [Multi-language Monorepo at Uber](https://eng.uber.com/ios-monorepo/)
