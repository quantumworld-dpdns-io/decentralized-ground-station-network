"""LangSmith client for LLM trace, debug, and evaluation."""
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

try:
    from langsmith import Client
    from langsmith import traceable
    from langsmith.run_trees import RunTree
    LANGSMITH_AVAILABLE = True
except ImportError:
    LANGSMITH_AVAILABLE = False


class LangSmithClient:
    """Wrapper for LangSmith tracing and evaluation."""

    def __init__(self, api_key: str = "", project_name: str = "ground-station-network"):
        self.api_key = api_key
        self.project_name = project_name
        self._client = None

    def _get_client(self):
        if self._client is None and LANGSMITH_AVAILABLE:
            self._client = Client(api_key=self.api_key or None)
        return self._client

    def trace(self, run_type: str = "chain", name: str = ""):
        """Decorator to trace a function with LangSmith."""
        if not LANGSMITH_AVAILABLE:
            def noop_decorator(func):
                return func
            return noop_decorator
        return traceable(run_type=run_type, name=name or None)

    async def log_run(self, name: str, inputs: dict, outputs: dict, metadata: dict | None = None):
        """Log a run to LangSmith."""
        client = self._get_client()
        if not client:
            logger.debug(f"[Mock LangSmith] Run: {name}")
            return
        try:
            run = client.create_run(
                name=name,
                inputs=inputs,
                outputs=outputs,
                project_name=self.project_name,
                extra={"metadata": metadata or {}},
            )
            logger.debug(f"LangSmith run created: {run.id}")
        except Exception as e:
            logger.warning(f"Failed to log run: {e}")

    async def evaluate(self, run_id: str, score: float, comment: str = "") -> dict:
        """Add evaluation feedback to a traced run."""
        client = self._get_client()
        if not client:
            return {"status": "mock", "run_id": run_id, "score": score}
        try:
            feedback = client.create_feedback(
                run_id=run_id,
                key="accuracy",
                score=score,
                comment=comment,
            )
            return {"status": "logged", "feedback_id": str(feedback.id)}
        except Exception as e:
            logger.warning(f"Failed to create feedback: {e}")
            return {"error": str(e)}

    async def get_traces(self, limit: int = 10) -> list[dict]:
        """Retrieve recent traces from LangSmith."""
        client = self._get_client()
        if not client:
            return []
        try:
            runs = client.list_runs(project_name=self.project_name, limit=limit)
            return [{"id": str(r.id), "name": r.name, "status": r.status} for r in runs]
        except Exception as e:
            logger.warning(f"Failed to list runs: {e}")
            return []


def traceable_agent(agent_name: str):
    """Decorator to make an agent's call traceable via LangSmith."""
    def decorator(func):
        if not LANGSMITH_AVAILABLE:
            return func
        return traceable(run_type="agent", name=agent_name)(func)
    return decorator
