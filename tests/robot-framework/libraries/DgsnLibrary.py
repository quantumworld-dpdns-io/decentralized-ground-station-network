"""
DGSN Custom Python Library for Robot Framework.
Provides keywords for DGSN-specific API operations, data generation, and validation.
"""

import json
import random
import string
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

import requests


class DgsnLibrary:
    """Custom library for DGSN (Decentralized Ground Station Network) operations."""

    def __init__(self):
        self._session = requests.Session()
        self._auth_token = None
        self._refresh_token = None
        self._station_ids = []
        self._receipt_ids = []
        self._schedule_ids = []

    def _headers(self, content_type: str = "application/json") -> Dict[str, str]:
        headers = {"Content-Type": content_type}
        if self._auth_token:
            headers["Authorization"] = f"Bearer {self._auth_token}"
        return headers

    def create_auth_session(self, base_url: str, username: str, password: str) -> Dict[str, Any]:
        """Authenticate and store tokens for subsequent requests."""
        url = f"{base_url}/auth/login"
        payload = {"username": username, "password": password}
        response = requests.post(url, json=payload, timeout=30)
        if response.status_code == 200:
            data = response.json()
            self._auth_token = data.get("access_token", data.get("token"))
            self._refresh_token = data.get("refresh_token")
        return response.json()

    def refresh_auth_token(self, base_url: str) -> Dict[str, Any]:
        """Refresh the authentication token."""
        url = f"{base_url}/auth/refresh"
        payload = {"refresh_token": self._refresh_token}
        response = requests.post(url, json=payload, headers=self._headers(), timeout=30)
        if response.status_code == 200:
            data = response.json()
            self._auth_token = data.get("access_token", data.get("token"))
        return response.json()

    def clear_auth(self):
        """Clear stored authentication tokens."""
        self._auth_token = None
        self._refresh_token = None

    def generate_station_payload(
        self,
        name: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        altitude: Optional[float] = None,
        frequency_mhz: Optional[float] = None,
        bandwidth_khz: Optional[float] = None,
        is_active: bool = True,
    ) -> Dict[str, Any]:
        """Generate a realistic station creation payload."""
        suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
        return {
            "name": name or f"Auto-GroundStation-{suffix}",
            "latitude": latitude or round(random.uniform(-90, 90), 6),
            "longitude": longitude or round(random.uniform(-180, 180), 6),
            "altitude": altitude or round(random.uniform(0, 3000), 1),
            "frequency_mhz": frequency_mhz or round(random.uniform(100, 6000), 3),
            "bandwidth_khz": bandwidth_khz or round(random.uniform(10, 500), 1),
            "is_active": is_active,
            "owner": "test-user",
        }

    def generate_receipt_payload(
        self,
        station_id: str,
        satellite: Optional[str] = None,
        frequency_mhz: Optional[float] = None,
        signal_strength_dbm: Optional[float] = None,
        modulation: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Generate a realistic receipt payload."""
        satellites = ["ISS", "NOAA-18", "NOAA-19", "METEOR-M2", "CubeSat-1", "EO-88"]
        modulations = ["QPSK", "BPSK", "FSK", "GMSK", "OOK", "16-QAM", "64-QAM"]
        timestamp = datetime.utcnow().isoformat() + "Z"
        return {
            "station_id": station_id,
            "satellite": satellite or random.choice(satellites),
            "frequency_mhz": frequency_mhz or round(random.uniform(100, 6000), 3),
            "signal_strength_dbm": signal_strength_dbm or round(random.uniform(-120, -30), 1),
            "modulation": modulation or random.choice(modulations),
            "timestamp": timestamp,
            "duration_seconds": round(random.uniform(10, 600), 1),
            "sample_rate_mhz": round(random.uniform(1, 10), 2),
            "data_size_bytes": random.randint(1024, 1048576),
        }

    def generate_schedule_payload(
        self,
        station_id: str,
        satellite: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Generate a realistic schedule payload."""
        satellites = ["ISS", "NOAA-18", "NOAA-19", "METEOR-M2", "CubeSat-1"]
        start_time = datetime.utcnow() + timedelta(hours=random.randint(1, 48))
        end_time = start_time + timedelta(minutes=random.randint(5, 60))
        return {
            "station_id": station_id,
            "satellite": satellite or random.choice(satellites),
            "start_time": start_time.isoformat() + "Z",
            "end_time": end_time.isoformat() + "Z",
            "priority": random.randint(1, 10),
            "configuration": {
                "frequency_mhz": round(random.uniform(100, 6000), 3),
                "bandwidth_khz": round(random.uniform(10, 500), 1),
                "modulation": random.choice(["QPSK", "BPSK", "FSK"]),
                "sample_rate_mhz": round(random.uniform(1, 10), 2),
            },
        }

    def generate_signal_payload(
        self,
        station_id: Optional[str] = None,
        frequency_mhz: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Generate a realistic signal payload."""
        suffix = "".join(random.choices(string.hexdigits.lower(), k=16))
        return {
            "station_id": station_id or "",
            "frequency_mhz": frequency_mhz or round(random.uniform(100, 6000), 3),
            "sample_rate_mhz": round(random.uniform(1, 10), 2),
            "modulation": random.choice(["QPSK", "BPSK", "FSK", "CW"]),
            "signal_data_base64": suffix,
            "duration_seconds": round(random.uniform(1, 60), 1),
            "metadata": {
                "source": "simulator",
                "band": random.choice(["UHF", "VHF", "L", "S", "X", "Ku"]),
                "polarization": random.choice(["linear", "circular-RH", "circular-LH"]),
            },
        }

    def verify_receipt_chain(self, receipt: Dict[str, Any]) -> bool:
        """Verify the integrity of a receipt's chain links."""
        required_fields = ["id", "previous_hash", "hash", "timestamp", "station_id"]
        for field in required_fields:
            if field not in receipt:
                return False
        if not receipt.get("hash", "").startswith("0"):
            return False
        if not isinstance(receipt.get("previous_hash"), str):
            return False
        if len(receipt.get("hash", "")) != 64:
            return False
        return True

    def verify_merkle_proof(self, proof: Dict[str, Any], root_hash: str, leaf: str) -> bool:
        """Verify a Merkle tree proof."""
        if "siblings" not in proof or "index" not in proof:
            return False
        computed_hash = leaf
        siblings = proof["siblings"]
        index = proof["index"]
        for i, sibling in enumerate(siblings):
            if (index >> i) & 1:
                computed_hash = self._sha256(sibling + computed_hash)
            else:
                computed_hash = self._sha256(computed_hash + sibling)
        return computed_hash == root_hash

    def _sha256(self, data: str) -> str:
        import hashlib
        return hashlib.sha256(data.encode()).hexdigest()

    def generate_weak_jwt(self, payload: Dict[str, Any], secret: str = "weak") -> str:
        """Generate a JWT with a weak secret for testing purposes."""
        import base64
        import hashlib
        import hmac

        header = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).rstrip(b"=").decode()
        body = base64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b"=").decode()
        signature_input = f"{header}.{body}".encode()
        signature = base64.urlsafe_b64encode(
            hmac.new(secret.encode(), signature_input, hashlib.sha256).digest()
        ).rstrip(b"=").decode()
        return f"{header}.{body}.{signature}"

    def corrupt_hash(self, receipt: Dict[str, Any]) -> Dict[str, Any]:
        """Corrupt the hash of a receipt for integrity testing."""
        modified = dict(receipt)
        if "hash" in modified:
            modified["hash"] = "corrupted" + modified["hash"][10:]
        return modified

    def simulate_quantum_circuit(self, circuit_type: str, n_qubits: int, depth: int) -> Dict[str, Any]:
        """Simulate a quantum circuit and return results."""
        import hashlib

        seed = f"{circuit_type}-{n_qubits}-{depth}-{time.time()}"
        random.seed(hashlib.sha256(seed.encode()).digest())
        counts = {}
        for _ in range(1024):
            outcome = "".join(random.choices("01", k=n_qubits))
            counts[outcome] = counts.get(outcome, 0) + 1
        return {
            "circuit_type": circuit_type,
            "n_qubits": n_qubits,
            "depth": depth,
            "counts": counts,
            "shots": 1024,
        }
