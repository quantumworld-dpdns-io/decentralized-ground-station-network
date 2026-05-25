# DGSN System Architecture

## Overview

The Decentralized Ground Station Network (DGSN) is a multi-language distributed system that coordinates private and university-owned satellite ground stations using cryptographic proof-of-reception receipts. The architecture leverages post-quantum cryptography, quantum computing optimization, and advanced signal processing to enable trustless coordination.

## Architecture Diagram

```
+--------------------------------------------------------------------------------+
|                              DGSN Architecture                                |
+--------------------------------------------------------------------------------+
|                                                                                |
|  +------------------+  +-------------------+  +------------------------+      |
|  |   Next.js UI     |  |   REST/gRPC API   |  |   Grafana/Prometheus   |      |
|  |  (TypeScript)    |  |   (Go Backend)     |  |   (Observability)     |      |
|  +--------+---------+  +--------+----------+  +-----------+------------+      |
|           |                     |                         |                   |
|  +--------+---------------------+-------------------------+--------+          |
|  |                              Layer 1: API Gateway                    |      |
|  +------------------------------------+-------------------------------+      |
|                                       |                                       |
|  +------------------------------------+-------------------------------+      |
|  |                           Layer 2: Service Mesh                    |      |
|  +--+-------------+-------------+-------------+-------------+---------+      |
|     |             |             |             |             |                |
|  +--+------+ +----+------+ +---+------+ +---+------+ +----+------+          |
|  |  Go     | |  Rust     | | Python   | | Julia    | | Redis     |          |
|  | Backend | | Crypto    | | Quantum  | | Signal   | | Cache     |          |
|  | (gRPC)  | | Kernel    | | Engine   | | Process  | | (State)   |          |
|  +---------+ +-----------+ +----------+ +----------+ +-----------+          |
|       |            |              |            |            |                |
|  +----+------------+--------------+------------+------------+------+        |
|  |                        Layer 3: Data & Storage                    |        |
|  +--+---------+---------+---------+---------+---------+----------+---+        |
|     |         |         |         |         |         |          |            |
|  +--+---+ +---+----+ +--+---+ +--+---+ +--+---+ +---+--+ +-------+--+       |
|  |PG   | | Qdrant | | S3   | | Loki | | Tempo| | Redis| | Iceberg  |       |
|  |SQL  | | Vector | | Obj  | | Logs | |Trace | |State | | Lakehouse|       |
|  +-----+ +--------+ +------+ +------+ +------+ +------+ +----------+       |
+--------------------------------------------------------------------------------+
```

## Component Descriptions

### 1. Go Backend (`src/backend/`)
- **Framework**: gRPC with REST gateway (grpc-gateway)
- **Role**: API gateway, business logic, station management, scheduling
- **Ports**: gRPC 9090, HTTP 8080
- **Key libraries**: OpenTelemetry, Prometheus client, Viper config
- **Database**: PostgreSQL (primary), Redis (cache/state)

### 2. Rust Crypto Kernel (`src/crypto-kernel/`)
- **Role**: Post-quantum cryptographic operations
- **Algorithms**: ML-KEM (Kyber), ML-DSA (Dilithium), SLH-DSA (SPHINCS+)
- **Features**: Key generation, signing, verification, KDF, Merkle trees
- **Integration**: C FFI for cross-language calling, WASM for browser

### 3. Python Quantum Engine (`src/quantum-engine/`)
- **Role**: Quantum circuit construction, optimization, and simulation
- **Frameworks**: Qiskit 1.x, CUDA-Q (GPU acceleration)
- **Circuits**: QAOA scheduling, VQE optimization, QFT signal analysis
- **Integration**: gRPC server for circuit submission

### 4. Julia Signal Processing (`src/signal-processing/`)
- **Role**: RF signal capture, filtering, demodulation, classification
- **Libraries**: DSP.jl, FFTW.jl, Optim.jl
- **Capabilities**: SDR I/Q sample processing, modulation classification
- **Output**: Apache Arrow format for efficient data exchange

### 5. Frontend (`src/frontend/`)
- **Framework**: Next.js 14 (React)
- **Features**: Dashboard, station management, scheduling, real-time telemetry
- **State**: Server-side rendering, WebSocket for real-time updates

### 6. Infrastructure
- **Container**: Docker with docker-compose for local dev
- **Observability**: OpenTelemetry -> Tempo (traces), Loki (logs), Prometheus (metrics)
- **Storage**: PostgreSQL (relational), Qdrant (vector), Redis (cache)
- **Orchestration**: Kubernetes (production), Northflank/Zeabur (PaaS)

## Data Flow

```
Satellite Pass Prediction
         |
         v
Quantum Optimizer (Python)
  - QAOA scheduling circuit
  - VQE resource allocation
         |
         v
Schedule Controller (Go)
  - Assign stations to slots
  - Manage reservations
         |
         v
Ground Station (External)
  - Captures RF signal
  - Generates reception metrics
         |
         v
Signal Processor (Julia)
  - Wiener/Kalman filtering
  - Modulation classification
  - SNR estimation
         |
         v
Receipt Generator (Rust)
  - Creates Merkle tree proof
  - Signs with ML-DSA/SLH-DSA
  - Chains receipts for audit
         |
         v
Verification & Storage
  - Verify receipt chain
  - Store in PostgreSQL/Qdrant
  - Update station reputation
```

## Security Architecture

### Post-Quantum Cryptography
- **Key Encapsulation**: ML-KEM-768 (Kyber) for session key exchange
- **Digital Signatures**: ML-DSA-65 (Dilithium) for receipt signing
- **Stateless Signatures**: SLH-DSA-192s (SPHINCS+) for long-term identity
- **Key Derivation**: HKDF-SHA3-256 for key material derivation

### Network Security
- mTLS between all gRPC services
- OAuth 2.0 / OIDC for user authentication
- Cilium Tetragon for eBPF-based security monitoring

## Deployment

### Development
```bash
make docker-up  # Starts all services locally
```

### Production
- Kubernetes cluster with Helm charts
- GitOps via ArgoCD
- Canary deployments for backend services
- Blue/green for frontend

## Performance Characteristics

| Component          | Latency      | Throughput       | Scaling         |
|--------------------|-------------|------------------|-----------------|
| Go Backend         | <10ms       | 10k req/s        | Horizontal      |
| Rust Crypto        | <1ms/op     | 100k ops/s       | Horizontal      |
| Python Quantum     | 100ms-10s   | 10 circuits/s    | GPU parallel    |
| Julia Signal       | <100ms      | 1 Gbps IQ        | GPU accelerated |

## API Endpoints

- `POST /api/v1/stations` - Register station
- `GET /api/v1/stations/:id` - Get station details
- `POST /api/v1/receipts` - Create reception receipt
- `GET /api/v1/receipts/:id` - Verify receipt
- `POST /api/v1/schedule/optimize` - Run quantum schedule optimization
- `POST /api/v1/signal/process` - Process captured signal
- `POST /api/v1/quantum/circuit` - Submit quantum circuit
