"""Versioned prompt templates for ground station AI agents."""
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)


class PromptTemplate:
    """A versioned prompt template with metadata."""

    def __init__(self, name: str, template: str, version: str = "1.0.0",
                 description: str = "", variables: list[str] | None = None):
        self.name = name
        self.template = template
        self.version = version
        self.description = description
        self.variables = variables or []
        self.created_at = datetime.now(timezone.utc).isoformat()

    @property
    def hash(self) -> str:
        return hashlib.sha256(self.template.encode()).hexdigest()[:12]

    def format(self, **kwargs) -> str:
        return self.template.format(**kwargs)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "template": self.template,
            "version": self.version,
            "description": self.description,
            "variables": self.variables,
            "hash": self.hash,
            "created_at": self.created_at,
        }


class PromptManager:
    """Manager for versioned prompt templates."""

    def __init__(self):
        self._prompts: dict[str, list[PromptTemplate]] = {}
        self._load_defaults()

    def _load_defaults(self):
        defaults = [
            PromptTemplate(
                name="station_operator",
                template=(
                    "You are a Ground Station Operator managing satellite communication infrastructure.\n"
                    "Current stations: {stations}\n"
                    "Task: {task}\n"
                    "Provide a concise operational response."
                ),
                version="1.0.0",
                description="Prompt for station operator agent",
                variables=["stations", "task"],
            ),
            PromptTemplate(
                name="quantum_designer",
                template=(
                    "You are a Quantum Circuit Designer specializing in RF signal processing.\n"
                    "Qubits available: {num_qubits}\n"
                    "Max depth: {max_depth}\n"
                    "Task: {task}\n"
                    "Provide a circuit design with gate sequence and fidelity estimate."
                ),
                version="1.0.0",
                description="Prompt for quantum circuit designer agent",
                variables=["num_qubits", "max_depth", "task"],
            ),
            PromptTemplate(
                name="signal_analyst",
                template=(
                    "You are a Signal Analyst with expertise in RF signal processing.\n"
                    "Signal metadata: {signal_metadata}\n"
                    "Task: {task}\n"
                    "Provide classification, metrics, and analysis."
                ),
                version="1.0.0",
                description="Prompt for signal analyst agent",
                variables=["signal_metadata", "task"],
            ),
            PromptTemplate(
                name="security_monitor",
                template=(
                    "You are a Security Monitor protecting ground station infrastructure.\n"
                    "Recent alerts: {alerts}\n"
                    "Task: {task}\n"
                    "Provide security assessment and recommendations."
                ),
                version="1.0.0",
                description="Prompt for security monitor agent",
                variables=["alerts", "task"],
            ),
        ]
        for prompt in defaults:
            self.register(prompt)

    def register(self, prompt: PromptTemplate):
        """Register a new prompt template."""
        if prompt.name not in self._prompts:
            self._prompts[prompt.name] = []
        self._prompts[prompt.name].append(prompt)
        logger.info(f"Registered prompt '{prompt.name}' v{prompt.version}")

    def get(self, name: str, version: str = "") -> PromptTemplate | None:
        """Get a prompt template by name and optional version."""
        prompts = self._prompts.get(name, [])
        if not prompts:
            return None
        if version:
            for p in prompts:
                if p.version == version:
                    return p
            return None
        return prompts[-1]

    def get_latest(self, name: str) -> PromptTemplate | None:
        """Get the latest version of a named prompt."""
        prompts = self._prompts.get(name, [])
        return prompts[-1] if prompts else None

    def list_prompts(self) -> list[dict[str, Any]]:
        """List all registered prompts with metadata."""
        result = []
        for name, versions in self._prompts.items():
            for p in versions:
                result.append(p.to_dict())
        return result

    def format_prompt(self, name: str, **kwargs) -> str:
        """Format a named prompt with variables."""
        prompt = self.get(name)
        if not prompt:
            raise ValueError(f"Prompt '{name}' not found")
        return prompt.format(**kwargs)

    def create_version(self, name: str, new_template: str, description: str = "") -> PromptTemplate:
        """Create a new version of an existing prompt."""
        existing = self.get(name)
        if not existing:
            raise ValueError(f"Prompt '{name}' not found")
        version_parts = existing.version.split(".")
        new_version = f"{version_parts[0]}.{int(version_parts[1]) + 1}.0"
        prompt = PromptTemplate(
            name=name,
            template=new_template,
            version=new_version,
            description=description or existing.description,
            variables=existing.variables,
        )
        self.register(prompt)
        return prompt
