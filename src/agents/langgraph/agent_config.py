"""Agent configuration for LangGraph workflows - LLM selection and tool binding."""
import logging
from dataclasses import dataclass, field
from typing import Any, Callable

from .state import AgentContext

logger = logging.getLogger(__name__)


@dataclass
class AgentConfig:
    name: str
    model: str = "gpt-4o"
    temperature: float = 0.1
    max_tokens: int = 2048
    system_prompt: str = ""
    tools: list[str] = field(default_factory=list)
    max_retries: int = 3
    timeout: int = 30


DEFAULT_AGENTS: dict[str, AgentConfig] = {
    "station_operator": AgentConfig(
        name="station_operator",
        model="gpt-4o",
        temperature=0.1,
        system_prompt="You are a ground station operator managing satellite communication infrastructure.",
        tools=["get_station", "list_stations", "update_status", "get_schedule"],
    ),
    "quantum_designer": AgentConfig(
        name="quantum_designer",
        model="gpt-4o",
        temperature=0.2,
        system_prompt="You are a quantum circuit designer optimizing circuits for signal processing.",
        tools=["submit_circuit", "get_circuit_result", "estimate_cost", "list_circuits"],
    ),
    "signal_analyst": AgentConfig(
        name="signal_analyst",
        model="gpt-4o",
        temperature=0.1,
        system_prompt="You are a signal analyst processing and classifying RF signals.",
        tools=["process_signal", "get_metrics", "correlate", "classify"],
    ),
    "security_monitor": AgentConfig(
        name="security_monitor",
        model="gpt-4o",
        temperature=0.0,
        system_prompt="You are a security monitor auditing systems and detecting threats.",
        tools=["get_audit_log", "get_alerts", "scan_vulnerabilities"],
    ),
}


def get_agent_config(agent_name: str) -> AgentConfig | None:
    """Get configuration for a named agent."""
    return DEFAULT_AGENTS.get(agent_name)


def create_agent_context(agent_name: str) -> AgentContext | None:
    """Create an AgentContext from the default configuration."""
    config = get_agent_config(agent_name)
    if not config:
        return None
    return AgentContext(
        agent_id=agent_name,
        agent_name=config.name,
        model=config.model,
        temperature=config.temperature,
        max_tokens=config.max_tokens,
    )


def resolve_model(agent_name: str, preferred_model: str = "") -> str:
    """Resolve the best model for an agent, with override support."""
    if preferred_model:
        return preferred_model
    config = get_agent_config(agent_name)
    return config.model if config else "gpt-4o-mini"
