"""Task definitions for each CrewAI agent."""
import logging
from typing import Any

from crewai import Task

from .agents import (
    create_station_operator,
    create_quantum_engineer,
    create_signal_analyst,
    create_security_guard,
    create_network_optimizer,
)

logger = logging.getLogger(__name__)


def create_station_ops_task() -> Task:
    """Task: Check and report ground station status."""
    return Task(
        description=(
            "Check the status of all ground stations in the network. "
            "Report which stations are online, offline, or in maintenance. "
            "Include station capabilities and antenna configurations."
        ),
        expected_output=(
            "A JSON report with all ground stations, their statuses, uptime percentages, "
            "and available capabilities. Highlight any stations needing attention."
        ),
        agent=create_station_operator(),
    )


def create_quantum_design_task() -> Task:
    """Task: Design a quantum circuit for signal filtering."""
    return Task(
        description=(
            "Design a quantum circuit optimized for RF signal filtering. "
            "The circuit should use at most 12 qubits and have depth under 100. "
            "Include gate sequence, estimated fidelity, and cost estimate."
        ),
        expected_output=(
            "A complete quantum circuit specification including qubit count, gate sequence, "
            "estimated fidelity, and execution cost in USD."
        ),
        agent=create_quantum_engineer(),
    )


def create_signal_analysis_task() -> Task:
    """Task: Analyze and classify a received signal."""
    return Task(
        description=(
            "Analyze the incoming RF signal. Extract modulation type, symbol rate, "
            "SNR, and other key metrics. Classify the signal type and identify "
            "the likely transmitter."
        ),
        expected_output=(
            "A signal analysis report with modulation classification, quality metrics "
            "(SNR, BER, EVM), and confidence scores."
        ),
        agent=create_signal_analyst(),
    )


def create_security_audit_task() -> Task:
    """Task: Perform a security audit of the network."""
    return Task(
        description=(
            "Run a comprehensive security audit of the ground station network. "
            "Check for open ports, outdated certificates, unusual access patterns, "
            "and compliance with security policies."
        ),
        expected_output=(
            "A security audit report listing findings by severity (CRITICAL, HIGH, MEDIUM, LOW), "
            "with remediation recommendations for each finding."
        ),
        agent=create_security_guard(),
    )


def create_optimization_task() -> Task:
    """Task: Optimize the pass scheduling for upcoming satellite passes."""
    return Task(
        description=(
            "Optimize the schedule for the next 24 hours of satellite passes across "
            "all ground stations. Minimize conflicts, maximize data collection, "
            "and prioritize high-value satellites."
        ),
        expected_output=(
            "An optimized schedule with pass assignments, conflict resolutions, "
            "and expected data throughput for each pass."
        ),
        agent=create_network_optimizer(),
    )
