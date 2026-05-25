"""IBM Quantum backend connector with job management."""

from dataclasses import dataclass, field
from typing import Optional
import time

import numpy as np
from qiskit import QuantumCircuit
from qiskit.providers import JobStatus


@dataclass
class BackendConfig:
    hub: str = "ibm-q"
    group: str = "open"
    project: str = "main"
    instance: Optional[str] = None
    max_qubits: int = 32
    max_shots: int = 32000
    optimization_level: int = 3
    reservation_seconds: int = 600


@dataclass
class JobInfo:
    job_id: str
    status: str
    creation_time: float
    circuit_name: str
    shots: int
    result_available: bool = False


class IBMBackendConnector:
    def __init__(self, backend_name: str = "ibm_qasm_simulator", config: Optional[BackendConfig] = None):
        self.backend_name = backend_name
        self.config = config or BackendConfig()
        self._service = None
        self._backend = None
        self._connected = False
        self._jobs: dict[str, JobInfo] = {}

    def connect(self, token: Optional[str] = None) -> bool:
        try:
            from qiskit_ibm_runtime import QiskitRuntimeService
            if token:
                self._service = QiskitRuntimeService(channel="ibm_quantum", token=token)
            else:
                try:
                    self._service = QiskitRuntimeService(channel="ibm_quantum")
                except Exception:
                    self._service = QiskitRuntimeService(channel="ibm_quantum", instance=f"{self.config.hub}/{self.config.group}/{self.config.project}")
            self._backend = self._service.backend(self.backend_name)
            self._connected = True
            return True
        except ImportError:
            print("qiskit-ibm-runtime not installed. Install with: pip install qiskit-ibm-runtime")
            return False
        except Exception as e:
            print(f"Failed to connect to IBM Quantum: {e}")
            return False

    @property
    def connected(self) -> bool:
        return self._connected

    @property
    def backend(self):
        return self._backend

    def run(self, circuit: QuantumCircuit, shots: Optional[int] = None) -> Optional[str]:
        if not self._connected:
            raise RuntimeError("Not connected to IBM Quantum backend")
        run_shots = shots or self.config.max_shots
        try:
            job = self._backend.run(circuit, shots=min(run_shots, self.config.max_shots))
            job_id = job.job_id()
            self._jobs[job_id] = JobInfo(
                job_id=job_id,
                status="QUEUED",
                creation_time=time.time(),
                circuit_name=circuit.name if circuit.name else "unnamed",
                shots=run_shots,
            )
            return job_id
        except Exception as e:
            raise RuntimeError(f"Failed to submit job: {e}")

    def run_batch(self, circuits: list[QuantumCircuit], shots: Optional[int] = None) -> list[Optional[str]]:
        return [self.run(c, shots) for c in circuits]

    def get_job_status(self, job_id: str) -> str:
        if job_id not in self._jobs:
            return "UNKNOWN"
        try:
            from qiskit_ibm_runtime import QiskitRuntimeService
            service = QiskitRuntimeService()
            job = service.job(job_id)
            status = job.status()
            status_str = status.name if hasattr(status, 'name') else str(status)
            self._jobs[job_id].status = status_str
            return status_str
        except Exception:
            return self._jobs[job_id].status

    def get_result(self, job_id: str, timeout: int = 3600) -> Optional[dict]:
        if job_id not in self._jobs:
            return None
        try:
            from qiskit_ibm_runtime import QiskitRuntimeService
            service = QiskitRuntimeService()
            job = service.job(job_id)
            result = job.result(timeout=timeout)
            self._jobs[job_id].result_available = True
            self._jobs[job_id].status = "COMPLETED"
            if hasattr(result, 'get_counts'):
                return result.get_counts()
            return result
        except Exception as e:
            print(f"Failed to get result for job {job_id}: {e}")
            return None

    def wait_for_job(self, job_id: str, poll_interval: int = 5, timeout: int = 3600) -> bool:
        start = time.time()
        while time.time() - start < timeout:
            status = self.get_job_status(job_id)
            if status in ("COMPLETED", "DONE"):
                return True
            if status in ("ERROR", "CANCELLED"):
                return False
            time.sleep(poll_interval)
        return False

    def cancel_job(self, job_id: str) -> bool:
        try:
            from qiskit_ibm_runtime import QiskitRuntimeService
            service = QiskitRuntimeService()
            job = service.job(job_id)
            job.cancel()
            self._jobs[job_id].status = "CANCELLED"
            return True
        except Exception:
            return False

    def list_jobs(self, limit: int = 10) -> list[JobInfo]:
        return sorted(self._jobs.values(), key=lambda j: j.creation_time, reverse=True)[:limit]

    def get_backend_properties(self) -> dict:
        if not self._connected or self._backend is None:
            return {}
        try:
            props = self._backend.properties()
            if props:
                return {
                    "qubits": self._backend.num_qubits,
                    "basis_gates": self._backend.configuration().basis_gates,
                    "max_shots": self._backend.configuration().max_shots,
                    "name": self._backend.name,
                    "version": self._backend.configuration().backend_version,
                }
        except Exception:
            pass
        return {"name": self.backend_name}

    def estimate_job_cost(self, circuit: QuantumCircuit, shots: int = 4000) -> dict:
        num_qubits = circuit.num_qubits
        num_gates = circuit.size()
        estimated_time = num_gates * 50e-9 * shots
        return {
            "num_qubits": num_qubits,
            "num_gates": num_gates,
            "estimated_seconds": estimated_time,
            "shots": shots,
            "circuit_depth": circuit.depth(),
        }

    def disconnect(self):
        self._connected = False
        self._service = None
        self._backend = None

    def __repr__(self) -> str:
        return f"IBMBackendConnector(backend={self.backend_name}, connected={self._connected}, jobs={len(self._jobs)})"
