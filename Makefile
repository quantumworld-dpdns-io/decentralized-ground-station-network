SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.ONESHELL:
MAKEFLAGS += --warn-undefined-variables

PROJECT := decentralized-ground-station-network
VERSION := 0.1.0

GO_SRC := src/backend
RUST_SRC := src/crypto-kernel
PYTHON_SRC := src/quantum-engine
JULIA_SRC := src/signal-processing
FRONTEND_SRC := src/frontend
PROTO_SRC := src/proto

BUILD_DIR := dist
COVERAGE_DIR := coverage

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "$(PROJECT) Makefile"
	@echo "Version: $(VERSION)"
	@echo ""
	@echo "Build targets:"
	@echo "  build              Build all components"
	@echo "  build-go           Build Go backend"
	@echo "  build-rust         Build Rust crypto kernel"
	@echo "  build-python       Build Python quantum engine"
	@echo "  build-julia        Build Julia signal processing"
	@echo "  build-frontend     Build Next.js frontend"
	@echo "  build-proto        Compile protobuf definitions"
	@echo ""
	@echo "Test targets:"
	@echo "  test               Run all tests"
	@echo "  test-go            Run Go tests"
	@echo "  test-rust          Run Rust tests"
	@echo "  test-python        Run Python tests"
	@echo "  test-julia         Run Julia tests"
	@echo "  test-frontend      Run frontend tests"
	@echo ""
	@echo "Lint targets:"
	@echo "  lint               Lint all code"
	@echo "  lint-go            Lint Go code with golangci-lint"
	@echo "  lint-rust          Lint Rust code with clippy"
	@echo "  lint-python        Lint Python code with ruff"
	@echo "  lint-julia         Lint Julia code"
	@echo ""
	@echo "Clean targets:"
	@echo "  clean              Remove all build artifacts"
	@echo ""
	@echo "Docker targets:"
	@echo "  docker-build       Build all Docker images"
	@echo "  docker-up          Start all services with docker compose"
	@echo "  docker-down        Stop all services"
	@echo "  docker-logs        View service logs"
	@echo ""
	@echo "Proto targets:"
	@echo "  proto              Compile all protobuf definitions"
	@echo "  proto-go           Generate Go protobuf code"
	@echo "  proto-python       Generate Python protobuf code"
	@echo ""
	@echo "Deploy targets:"
	@echo "  deploy-local       Deploy to local environment"
	@echo "  deploy-staging     Deploy to staging"
	@echo "  deploy-production  Deploy to production"
	@echo ""
	@echo "Quantum targets:"
	@echo "  quantum-compile    Compile OpenQASM circuits"
	@echo "  quantum-bench      Run quantum benchmarks"
	@echo "  quantum-simulate   Simulate quantum circuits"
	@echo ""
	@echo "Utility:"
	@echo "  install-tools      Install build and dev tools"
	@echo "  pre-commit         Run pre-commit checks"
	@echo "  check-deps         Check for outdated dependencies"

build: build-go build-rust build-python build-julia build-frontend

build-go:
	@echo "Building Go backend..."
	@cd $(GO_SRC) && go build -o ../../$(BUILD_DIR)/dgsn-server ./cmd/dgsn-server/
	@echo "Go backend built: $(BUILD_DIR)/dgsn-server"

build-rust:
	@echo "Building Rust crypto kernel..."
	@cd $(RUST_SRC) && cargo build --release --features pqc
	@cp $(RUST_SRC)/target/release/libdgsn_crypto.so $(BUILD_DIR)/ 2>/dev/null || true
	@echo "Rust crypto kernel built"

build-python:
	@echo "Building Python quantum engine..."
	@cd $(PYTHON_SRC) && python -m build --wheel
	@cp $(PYTHON_SRC)/dist/*.whl $(BUILD_DIR)/ 2>/dev/null || true
	@echo "Python quantum engine built"

build-julia:
	@echo "Building Julia signal processing..."
	@cd $(JULIA_SRC) && julia -e 'using PackageCompiler; create_sysimage([:DGSN_SignalProcessing], sysimage_path="../../$(BUILD_DIR)/dgsn_signal.so")'
	@echo "Julia sysimage built: $(BUILD_DIR)/dgsn_signal.so"

build-frontend:
	@echo "Building frontend..."
	@cd $(FRONTEND_SRC) && npm run build
	@echo "Frontend built"

test: test-go test-rust test-python test-julia test-frontend

test-go:
	@echo "Running Go tests..."
	@cd $(GO_SRC) && go test -v -race -count=1 -coverprofile=../../$(COVERAGE_DIR)/go.out ./...

test-rust:
	@echo "Running Rust tests..."
	@cd $(RUST_SRC) && cargo test --features pqc

test-python:
	@echo "Running Python tests..."
	@cd $(PYTHON_SRC) && python -m pytest --verbose --cov=. --cov-report=term

test-julia:
	@echo "Running Julia tests..."
	@cd $(JULIA_SRC) && julia -e 'using Pkg; Pkg.test()'

test-frontend:
	@echo "Running frontend tests..."
	@cd $(FRONTEND_SRC) && npm test -- --coverage

lint: lint-go lint-rust lint-python

lint-go:
	@echo "Linting Go code..."
	@golangci-lint run $(GO_SRC)/...

lint-rust:
	@echo "Linting Rust code..."
	@cd $(RUST_SRC) && cargo clippy --all-targets --features pqc -- -D warnings

lint-python:
	@echo "Linting Python code..."
	@ruff check $(PYTHON_SRC)/

lint-julia:
	@echo "Linting Julia code..."
	@cd $(JULIA_SRC) && julia -e 'using JuliaFormatter; format("src")'

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(COVERAGE_DIR)
	cd $(GO_SRC) && go clean -cache
	cd $(RUST_SRC) && cargo clean
	cd $(PYTHON_SRC) && rm -rf build/ dist/ *.egg-info __pycache__/
	cd $(FRONTEND_SRC) && rm -rf .next/ out/ node_modules/
	@echo "Clean complete"

docker-build:
	@echo "Building Docker images..."
	docker compose -f deployments/docker/docker-compose.yml build

docker-up:
	@echo "Starting services..."
	docker compose -f deployments/docker/docker-compose.yml up -d

docker-down:
	@echo "Stopping services..."
	docker compose -f deployments/docker/docker-compose.yml down

docker-logs:
	@echo "Showing logs..."
	docker compose -f deployments/docker/docker-compose.yml logs -f

proto: proto-go proto-python

proto-go:
	@echo "Generating Go protobuf code..."
	@mkdir -p $(GO_SRC)/api/proto
	@protoc -I$(PROTO_SRC) --go_out=$(GO_SRC)/api/proto --go_opt=paths=source_relative \
		--go-grpc_out=$(GO_SRC)/api/proto --go-grpc_opt=paths=source_relative \
		--grpc-gateway_out=$(GO_SRC)/api/proto --grpc-gateway_opt=paths=source_relative \
		$(PROTO_SRC)/dgsn/v1/*.proto $(PROTO_SRC)/quantum/v1/*.proto $(PROTO_SRC)/signal/v1/*.proto

proto-python:
	@echo "Generating Python protobuf code..."
	@mkdir -p $(PYTHON_SRC)/proto
	@python -m grpc_tools.protoc -I$(PROTO_SRC) --python_out=$(PYTHON_SRC)/proto \
		--grpc_python_out=$(PYTHON_SRC)/proto \
		$(PROTO_SRC)/dgsn/v1/*.proto $(PROTO_SRC)/quantum/v1/*.proto $(PROTO_SRC)/signal/v1/*.proto

deploy-local:
	@echo "Deploying locally..."
	docker compose -f deployments/docker/docker-compose.yml up -d

deploy-staging:
	@echo "Deploying to staging..."
	@echo "Placeholder: kubectl apply -f deployments/kubernetes/staging/"

deploy-production:
	@echo "Deploying to production..."
	@echo "Placeholder: kubectl apply -f deployments/kubernetes/production/"

quantum-compile:
	@echo "Compiling OpenQASM circuits..."
	@scripts/quantum/circuits/compile_qasm.sh

quantum-bench:
	@echo "Running quantum benchmarks..."
	@cd $(PYTHON_SRC) && python -m pytest benchmarks/ --benchmark-only

quantum-simulate:
	@echo "Simulating quantum circuits..."
	@cd $(PYTHON_SRC) && python -m pytest circuits/tests/ --benchmark-only

install-tools:
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest
	pip install ruff mypy pytest pytest-cov pre-commit
	rustup component add clippy rustfmt

pre-commit:
	@echo "Running pre-commit checks..."
	pre-commit run --all-files
	lint-go
	lint-rust
	lint-python
	test-go
	test-rust
	test-python

check-deps:
	@echo "Checking for outdated dependencies..."
	cd $(GO_SRC) && go list -u -m all | grep '\['
	cd $(RUST_SRC) && cargo outdated
	cd $(PYTHON_SRC) && pip list --outdated
	cd $(FRONTEND_SRC) && npm outdated

.PHONY: help build test lint clean docker proto deploy quantum install-tools pre-commit check-deps
