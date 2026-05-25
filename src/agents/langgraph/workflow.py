"""LangGraph workflow definition for multi-agent orchestration."""
import json
import logging
from typing import Any

from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

from .state import WorkflowState
from .nodes import station_operator_node, quantum_designer_node, signal_analyst_node, security_monitor_node
from .edges import route_by_agent, should_continue

logger = logging.getLogger(__name__)


def create_workflow() -> StateGraph:
    """Create and configure the LangGraph workflow with all nodes and edges."""
    workflow = StateGraph(WorkflowState)

    workflow.add_node("station_operator", station_operator_node)
    workflow.add_node("quantum_designer", quantum_designer_node)
    workflow.add_node("signal_analyst", signal_analyst_node)
    workflow.add_node("security_monitor", security_monitor_node)

    workflow.set_entry_point("station_operator")

    workflow.add_conditional_edges("station_operator", route_by_agent, {
        "station_operator": "station_operator",
        "quantum_designer": "quantum_designer",
        "signal_analyst": "signal_analyst",
        "security_monitor": "security_monitor",
        "end": END,
    })
    workflow.add_conditional_edges("quantum_designer", route_by_agent, {
        "station_operator": "station_operator",
        "quantum_designer": "quantum_designer",
        "signal_analyst": "signal_analyst",
        "security_monitor": "security_monitor",
        "end": END,
    })
    workflow.add_conditional_edges("signal_analyst", route_by_agent, {
        "station_operator": "station_operator",
        "quantum_designer": "quantum_designer",
        "signal_analyst": "signal_analyst",
        "security_monitor": "security_monitor",
        "end": END,
    })
    workflow.add_conditional_edges("security_monitor", route_by_agent, {
        "station_operator": "station_operator",
        "quantum_designer": "quantum_designer",
        "signal_analyst": "signal_analyst",
        "security_monitor": "security_monitor",
        "end": END,
    })

    return workflow


def compile_workflow() -> Any:
    """Compile the workflow with checkpointing."""
    workflow = create_workflow()
    memory = MemorySaver()
    return workflow.compile(checkpointer=memory)


async def run_workflow(session_id: str = "default-session", initial_context: dict | None = None) -> dict[str, Any]:
    """Run the multi-agent workflow end-to-end."""
    app = compile_workflow()
    config = {"configurable": {"thread_id": session_id}}

    initial_state = WorkflowState(
        session_id=session_id,
        context=initial_context or {},
    )

    final_state = await app.ainvoke(initial_state, config)
    return {
        "session_id": session_id,
        "completed": final_state.completed,
        "messages": final_state.messages,
        "tasks": {k: {"status": v.status, "result": v.result, "error": v.error} for k, v in final_state.tasks.items()},
        "context": final_state.context,
        "errors": final_state.errors,
    }
