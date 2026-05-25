"""Agent definitions for CrewAI-based multi-agent system."""
import logging
from typing import Any

from crewai import Agent

from .tools import station_info_tool, schedule_tool, signal_classify_tool, security_scan_tool

logger = logging.getLogger(__name__)


def create_station_operator() -> Agent:
    """Create the Ground Station Operator agent."""
    return Agent(
        role="Ground Station Operator",
        goal="Manage ground station network operations, monitor status, and coordinate satellite passes",
        backstory=(
            "You are an expert ground station operator with years of experience managing "
            "satellite communication networks. You monitor station health, schedule passes, "
            "and ensure reliable data downlinks from orbiting satellites."
        ),
        tools=[station_info_tool, schedule_tool],
        verbose=True,
        allow_delegation=True,
        max_iter=15,
        max_rpm=30,
    )


def create_quantum_engineer() -> Agent:
    """Create the Quantum Engineer agent."""
    return Agent(
        role="Quantum Circuit Engineer",
        goal="Design and optimize quantum circuits for advanced signal processing tasks",
        backstory=(
            "You specialize in designing quantum circuits that process RF signals with "
            "higher fidelity than classical methods. You optimize gate depth, minimize "
            "decoherence, and push the limits of NISQ-era devices."
        ),
        verbose=True,
        allow_delegation=False,
        max_iter=10,
    )


def create_signal_analyst() -> Agent:
    """Create the Signal Analyst agent."""
    return Agent(
        role="Signal Analyst",
        goal="Analyze, classify, and fingerprint RF signals from satellite and terrestrial sources",
        backstory=(
            "You have deep expertise in RF signal processing, modulation recognition, "
            "and emitter fingerprinting. You can identify the type, origin, and intent "
            "of any signal intercepted by the ground station network."
        ),
        tools=[signal_classify_tool],
        verbose=True,
        allow_delegation=True,
        max_iter=15,
    )


def create_security_guard() -> Agent:
    """Create the Security Guard agent."""
    return Agent(
        role="Security Guard",
        goal="Monitor ground station security, detect intrusions, and ensure compliance",
        backstory=(
            "You are a cybersecurity expert focused on protecting ground station infrastructure. "
            "You monitor for unauthorized access, scan for vulnerabilities, and enforce "
            "security policies across the distributed network."
        ),
        tools=[security_scan_tool],
        verbose=True,
        allow_delegation=False,
        max_iter=10,
    )


def create_network_optimizer() -> Agent:
    """Create the Network Optimizer agent."""
    return Agent(
        role="Network Optimizer",
        goal="Optimize ground station scheduling, resource allocation, and data routing",
        backstory=(
            "You optimize the entire ground station network for maximum throughput and "
            "minimum latency. You balance competing priorities, allocate bandwidth, and "
            "route data through the most efficient paths."
        ),
        verbose=True,
        allow_delegation=True,
        max_iter=15,
    )
