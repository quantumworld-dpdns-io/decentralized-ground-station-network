"""Skill registry with discovery, versioning, and metadata."""
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable

logger = logging.getLogger(__name__)


@dataclass
class SkillMetadata:
    name: str
    version: str
    description: str
    author: str = "decentralized-ground-station-network"
    dependencies: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    registered_at: str = ""


class SkillRegistry:
    """Registry for discovering and managing skills."""

    def __init__(self):
        self._skills: dict[str, SkillMetadata] = {}
        self._modules: dict[str, object] = {}

    def register(self, module: object, metadata: SkillMetadata):
        """Register a skill module with its metadata."""
        if not metadata.registered_at:
            metadata.registered_at = datetime.now(timezone.utc).isoformat()
        self._skills[metadata.name] = metadata
        self._modules[metadata.name] = module
        logger.info(f"Registered skill '{metadata.name}' v{metadata.version}")

    def discover(self, tag: str = "") -> list[SkillMetadata]:
        """Discover all registered skills, optionally filtered by tag."""
        if not tag:
            return list(self._skills.values())
        return [s for s in self._skills.values() if tag in s.tags]

    def get(self, name: str) -> SkillMetadata | None:
        """Get metadata for a named skill."""
        return self._skills.get(name)

    def get_module(self, name: str) -> object:
        """Get the module object for a named skill."""
        return self._modules.get(name)

    def unregister(self, name: str) -> bool:
        """Unregister a skill by name."""
        if name in self._skills:
            del self._skills[name]
            del self._modules[name]
            logger.info(f"Unregistered skill '{name}'")
            return True
        return False

    def list_versions(self, name: str) -> list[str]:
        """List all known versions of a skill."""
        skill = self._skills.get(name)
        if skill:
            return [skill.version]
        return []

    @property
    def count(self) -> int:
        return len(self._skills)


_default_registry = SkillRegistry()


def get_registry() -> SkillRegistry:
    """Get the default global skill registry."""
    return _default_registry


def register_default_skills():
    """Register all built-in skills in the default registry."""
    import src.agents.skills.station_ops as station_ops
    import src.agents.skills.quantum_circuit as quantum_circuit
    import src.agents.skills.signal_analysis as signal_analysis
    import src.agents.skills.security_audit as security_audit
    import src.agents.skills.scheduling as scheduling

    registry = get_registry()
    registry.register(station_ops, SkillMetadata(
        name="station_ops",
        version="1.0.0",
        description="Register, configure, and monitor ground stations",
        tags=["station", "operations", "infrastructure"],
    ))
    registry.register(quantum_circuit, SkillMetadata(
        name="quantum_circuit",
        version="1.0.0",
        description="Design, optimize, and execute quantum circuits",
        tags=["quantum", "circuit", "computation"],
    ))
    registry.register(signal_analysis, SkillMetadata(
        name="signal_analysis",
        version="1.0.0",
        description="Process, classify, and fingerprint RF signals",
        tags=["signal", "rf", "analysis"],
    ))
    registry.register(security_audit, SkillMetadata(
        name="security_audit",
        version="1.0.0",
        description="Scan, analyze, and report on security posture",
        tags=["security", "audit", "compliance"],
    ))
    registry.register(scheduling, SkillMetadata(
        name="scheduling",
        version="1.0.0",
        description="Optimize, assign, and resolve conflicts for satellite passes",
        tags=["scheduling", "optimization"],
    ))
    logger.info(f"Registered {registry.count} default skills")
