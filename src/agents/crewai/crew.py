"""CrewAI crew definition with all agents and tasks."""
import logging
from typing import Any

from crewai import Crew, Process

from .agents import (
    create_station_operator,
    create_quantum_engineer,
    create_signal_analyst,
    create_security_guard,
    create_network_optimizer,
)
from .tasks import (
    create_station_ops_task,
    create_quantum_design_task,
    create_signal_analysis_task,
    create_security_audit_task,
    create_optimization_task,
)

logger = logging.getLogger(__name__)


def create_ground_station_crew() -> Crew:
    """Create the complete ground station operations crew."""
    station_operator = create_station_operator()
    quantum_engineer = create_quantum_engineer()
    signal_analyst = create_signal_analyst()
    security_guard = create_security_guard()
    network_optimizer = create_network_optimizer()

    station_task = create_station_ops_task()
    quantum_task = create_quantum_design_task()
    signal_task = create_signal_analysis_task()
    security_task = create_security_audit_task()
    optimization_task = create_optimization_task()

    crew = Crew(
        agents=[station_operator, quantum_engineer, signal_analyst, security_guard, network_optimizer],
        tasks=[station_task, quantum_task, signal_task, security_task, optimization_task],
        process=Process.sequential,
        verbose=True,
        max_rpm=30,
        share_crew=True,
    )
    return crew


async def run_crew(inputs: dict[str, Any] | None = None) -> dict[str, Any]:
    """Run the ground station crew with optional inputs."""
    crew = create_ground_station_crew()
    logger.info("Starting crew execution...")
    result = crew.kickoff(inputs=inputs or {})
    return {
        "status": "completed",
        "result": str(result),
        "agents": [a.role for a in crew.agents],
        "tasks": [t.description for t in crew.tasks],
    }
