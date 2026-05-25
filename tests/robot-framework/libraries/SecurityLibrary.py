"""
Security Library for Robot Framework.
Provides keywords for security testing: SSL/TLS, JWT, SQL injection, XSS, etc.
"""

import base64
import hashlib
import hmac
import ipaddress
import json
import random
import re
import socket
import ssl
import string
import time
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse


class SecurityLibrary:
    """Custom library for security testing helpers."""

    def __init__(self):
        self._observed_headers = {}
        self._tls_info = {}

    def check_tls_cipher_strength(self, hostname: str, port: int = 443) -> Dict[str, Any]:
        """Check TLS cipher suite strength and security properties."""
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        weak_ciphers = []
        strong_ciphers = []
        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cipher = ssock.cipher()
                version = ssock.version()
                result = {
                    "hostname": hostname,
                    "port": port,
                    "tls_version": version,
                    "current_cipher": cipher[0],
                    "current_key_exchange": cipher[1],
                    "current_bits": cipher[2],
                }
                if "TLSv1.0" in version or "TLSv1.1" in version:
                    result["weak"] = True
                    result["reason"] = f"Outdated TLS version: {version}"
                elif cipher[2] < 128:
                    result["weak"] = True
                    result["reason"] = f"Weak key size: {cipher[2]} bits"
                else:
                    result["weak"] = False
                    result["reason"] = "Acceptable cipher strength"
                self._tls_info = result
                return result

    def check_certificate_validation(self, hostname: str, port: int = 443) -> Dict[str, Any]:
        """Check certificate validation behavior."""
        result = {"hostname": hostname, "port": port, "validates": True, "errors": []}
        context = ssl.create_default_context()
        try:
            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    if not cert:
                        result["validates"] = False
                        result["errors"].append("No certificate returned")
                    else:
                        result["subject"] = dict(cert.get("subject", []))
                        result["issuer"] = dict(cert.get("issuer", []))
                        result["expiry"] = cert.get("notAfter", "unknown")
        except ssl.SSLCertVerificationError as e:
            result["validates"] = False
            result["errors"].append(str(e))
        except Exception as e:
            result["validates"] = False
            result["errors"].append(str(e))
        return result

    def parse_jwt(self, token: str) -> Dict[str, Any]:
        """Parse and decode a JWT token (without verification)."""
        parts = token.split(".")
        if len(parts) != 3:
            return {"valid": False, "error": "Malformed JWT"}
        try:
            header_b64 = parts[0]
            payload_b64 = parts[1]
            header_b64 += "=" * (4 - len(header_b64) % 4)
            payload_b64 += "=" * (4 - len(payload_b64) % 4)
            header = json.loads(base64.urlsafe_b64decode(header_b64).decode())
            payload = json.loads(base64.urlsafe_b64decode(payload_b64).decode())
            return {"valid": True, "header": header, "payload": payload}
        except Exception as e:
            return {"valid": False, "error": str(e)}

    def check_jwt_algorithm(self, token: str) -> Tuple[bool, str]:
        """Check if JWT uses a weak/none algorithm."""
        parsed = self.parse_jwt(token)
        if not parsed.get("valid"):
            return False, "Invalid JWT format"
        alg = parsed.get("header", {}).get("alg", "").lower()
        if alg == "none":
            return True, "JWT uses 'none' algorithm - VULNERABLE"
        if alg in ["hs256", "hs384", "hs512"]:
            return True, f"JWT uses symmetric algorithm: {alg}"
        if alg in ["rs256", "rs384", "rs512", "es256", "es384", "es512"]:
            return False, f"JWT uses asymmetric algorithm: {alg}"
        return False, f"JWT uses algorithm: {alg}"

    def check_security_headers(self, headers: Dict[str, str]) -> Dict[str, Any]:
        """Check for presence and strength of security headers."""
        checks = {
            "strict-transport-security": {"present": False, "valid": False, "max_age": 0},
            "content-security-policy": {"present": False, "valid": False, "directives": ""},
            "x-frame-options": {"present": False, "valid": False, "value": ""},
            "x-content-type-options": {"present": False, "valid": False, "value": ""},
            "referrer-policy": {"present": False, "valid": False, "value": ""},
            "permissions-policy": {"present": False, "valid": False, "value": ""},
        }
        headers_lower = {k.lower(): v for k, v in headers.items()}
        for header in checks:
            if header in headers_lower:
                checks[header]["present"] = True
                checks[header]["value"] = headers_lower[header]
        if checks["strict-transport-security"]["present"]:
            hsts = headers_lower["strict-transport-security"]
            checks["strict-transport-security"]["value"] = hsts
            match = re.search(r"max-age=(\d+)", hsts)
            if match:
                max_age = int(match.group(1))
                checks["strict-transport-security"]["max_age"] = max_age
                checks["strict-transport-security"]["valid"] = max_age >= 31536000
            checks["strict-transport-security"]["includes_subdomains"] = "includesubdomains" in hsts.lower()
        if checks["x-frame-options"]["present"]:
            value = headers_lower["x-frame-options"].upper()
            checks["x-frame-options"]["valid"] = value in ["DENY", "SAMEORIGIN"]
        if checks["x-content-type-options"]["present"]:
            value = headers_lower["x-content-type-options"].lower()
            checks["x-content-type-options"]["valid"] = value == "nosniff"
        self._observed_headers = checks
        return checks

    def has_all_security_headers(self) -> Tuple[bool, List[str]]:
        """Check if all recommended security headers are present."""
        missing = []
        for header, info in self._observed_headers.items():
            if not info.get("present", False):
                missing.append(header)
        return len(missing) == 0, missing

    def check_password_strength(self, password: str) -> Dict[str, Any]:
        """Evaluate password strength against common criteria."""
        checks = {
            "length": len(password) >= 12,
            "uppercase": bool(re.search(r"[A-Z]", password)),
            "lowercase": bool(re.search(r"[a-z]", password)),
            "digit": bool(re.search(r"\d", password)),
            "special": bool(re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=\[\]\\;'/`~]", password)),
            "no_common": password.lower() not in [
                "password", "password123", "admin", "admin123", "12345678",
                "qwerty123", "letmein", "welcome",
            ],
        }
        passed = sum(1 for v in checks.values() if v)
        if passed >= 6:
            strength = "strong"
        elif passed >= 4:
            strength = "moderate"
        else:
            strength = "weak"
        return {"checks": checks, "passed": passed, "strength": strength}

    def generate_sql_injection_payloads(self) -> List[Dict[str, str]]:
        """Generate common SQL injection payloads for testing."""
        return [
            {"name": "Simple OR", "payload": "' OR '1'='1"},
            {"name": "Comment injection", "payload": "admin'--"},
            {"name": "Union select", "payload": "' UNION SELECT * FROM users; --"},
            {"name": "Blind boolean", "payload": "' AND 1=1; --"},
            {"name": "Blind false", "payload": "' AND 1=0; --"},
            {"name": "Stacked query", "payload": "'; DROP TABLE users; --"},
            {"name": "Time-based blind", "payload": "' OR SLEEP(5); --"},
            {"name": "Error-based", "payload": "' OR 1=CONVERT(int, @@version); --"},
            {"name": "LIKE injection", "payload": "' OR 1=1 LIKE '%"},
            {"name": "Hex encoding", "payload": "0x27204f5220313d312d2d"},
        ]

    def generate_xss_payloads(self) -> List[Dict[str, str]]:
        """Generate common XSS payloads for testing."""
        return [
            {"name": "Basic script", "payload": "<script>alert('xss')</script>"},
            {"name": "IMG onerror", "payload": "<img src=x onerror=alert('xss')>"},
            {"name": "SVG onload", "payload": "<svg onload=alert('xss')>"},
            {"name": "Body onload", "payload": "<body onload=alert('xss')>"},
            {"name": "Iframe", "payload": "<iframe src=javascript:alert('xss')>"},
            {"name": "Link tag", "payload": "<link rel=import href=javascript:alert('xss')>"},
            {"name": "Encoded chars", "payload": "&#60;script&#62;alert('xss')&#60;/script&#62;"},
            {"name": "Double quote break", "payload": "\";alert('xss');//"},
            {"name": "DOM-based", "payload": "#<script>alert('xss')</script>"},
            {"name": "Polyglot", "payload": "jaVasCript:/*-/*`/*\\`/*'/*\"/**/(/* */oNcliCk=alert() )//%0D%0A%0d%0a</stYle/</titLe/</teXtarEa/</scRipt/--!>\\x3csVg/<sVg/oNloAd=alert()//>\\x3e"},
        ]

    def check_internal_ip(self, url: str) -> Tuple[bool, str]:
        """Check if a URL resolves to an internal/private IP address."""
        parsed = urlparse(url)
        hostname = parsed.hostname or url
        try:
            ip = socket.gethostbyname(hostname)
            addr = ipaddress.ip_address(ip)
            if addr.is_private:
                return True, f"Resolves to private IP: {ip}"
            if addr.is_loopback:
                return True, f"Resolves to loopback: {ip}"
            return False, f"Resolves to public IP: {ip}"
        except Exception as e:
            return False, f"Could not resolve: {str(e)}"

    def generate_dns_rebind_payload(self, original_domain: str, internal_ip: str) -> List[str]:
        """Generate DNS rebinding attack payloads."""
        rebind_services = [
            f"http://{original_domain}.{internal_ip}.xip.io",
            f"http://{original_domain}.{internal_ip}.nip.io",
            f"http://{original_domain}.{internal_ip}.sslip.io",
            f"http://internal-{internal_ip.replace('.', '-')}.traefik.me",
        ]
        return rebind_services

    def check_ssrf_payload(self, url: str) -> Dict[str, Any]:
        """Check if a URL is potentially an SSRF attack vector."""
        warnings = []
        parsed = urlparse(url)
        scheme = parsed.scheme.lower() if parsed.scheme else ""
        if scheme in ["file", "gopher", "dict"]:
            warnings.append(f"Dangerous URL scheme: {scheme}")
        hostname = parsed.hostname or ""
        if hostname in ["169.254.169.254", "metadata.google.internal", "100.100.100.200"]:
            warnings.append(f"Cloud metadata endpoint: {hostname}")
        try:
            ip = socket.gethostbyname(hostname)
            addr = ipaddress.ip_address(ip)
            if addr.is_private or addr.is_loopback:
                warnings.append(f"Internal IP address: {ip}")
        except Exception:
            pass
        return {"url": url, "dangerous": len(warnings) > 0, "warnings": warnings}

    def validate_log_content(self, log_content: str) -> Dict[str, Any]:
        """Check log content for sensitive data exposure."""
        sensitive_patterns = {
            "password": r"(?i)password\s*[=:]\s*\S+",
            "credit_card": r"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b",
            "email": r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b",
            "api_key": r"(?i)(api[_-]?key|apikey)\s*[=:]\s*\S+",
            "secret": r"(?i)(secret|token|private.key)\s*[=:]\s*\S+",
            "ssn": r"\b\d{3}-\d{2}-\d{4}\b",
            "jwt": r"eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",
        }
        findings = {}
        for pattern_name, pattern in sensitive_patterns.items():
            matches = re.findall(pattern, log_content)
            if matches:
                findings[pattern_name] = len(matches)
        return {"safe": len(findings) == 0, "findings": findings}

    def check_directory_listing(self, base_url: str, paths: List[str]) -> List[Dict[str, Any]]:
        """Check for directory listing vulnerabilities."""
        import requests
        results = []
        for path in paths:
            url = f"{base_url}{path}"
            try:
                response = requests.get(url, timeout=10, allow_redirects=False)
                body = response.text.lower()
                has_listing = any(
                    indicator in body
                    for indicator in [
                        "index of",
                        "<title>index of",
                        "parent directory",
                        "directory listing",
                    ]
                )
                results.append({
                    "path": path,
                    "status": response.status_code,
                    "listing": has_listing,
                    "size": len(body),
                })
            except Exception as e:
                results.append({"path": path, "status": 0, "listing": False, "error": str(e)})
        return results

    def check_cors(self, headers: Dict[str, str], origin: str = "https://evil.com") -> Tuple[bool, str]:
        """Check if CORS headers are overpermissive."""
        cors_headers = {k.lower(): v for k, v in headers.items()}
        allow_origin = cors_headers.get("access-control-allow-origin", "")
        allow_credentials = cors_headers.get("access-control-allow-credentials", "false")
        if allow_origin == "*" and allow_credentials.lower() == "true":
            return True, "Wildcard origin with credentials - VULNERABLE"
        if allow_origin == "*":
            return True, "Wildcard CORS origin - permissive"
        if origin in allow_origin:
            return True, f"Reflected CORS origin: {origin}"
        return False, "CORS configuration acceptable"
