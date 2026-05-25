"""Conditional edges for workflow routing in LangGraph."""
import logging
from typing import Literal

from .state import WorkflowState

logger = logging.getLogger(__name__)


def route_by_agent(state: WorkflowState) -> Literal["station_operator", "quantum_designer", "signal_analyst", "security_monitor", "end"]:
    """Route to the next node based on current workflow state and errors."""
    if state.get_errors():
        logger.warning(f"Routing to end due to {len(state.get_errors())} error(s)")
        return "end"

    completed = sum(1 for t in state.tasks.values() if t.status == "completed")
    failed = sum(1 for t in state.tasks.values() if t.status == "failed")
    total = len(state.tasks)

    if failed > 0:
        return "end"

    if completed == total:
        return "end"

    return "station_operator"


def should_continue(state: WorkflowState) -> Literal["continue", "end"]:
    """Determine if the workflow should continue or end."""
    if state.is_complete():
        logger.info("Workflow complete, ending")
        return "end"
    return "continue"


def has_errors(state: WorkflowState) -> Literal["handle_error", "continue"]:
    """Route to error handling if errors exist, otherwise continue."""
    if state.get_errors():
        return "handle_error"
    return "continue"
