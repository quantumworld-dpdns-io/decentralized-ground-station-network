"""W&B Weave integration for LLM tracing and observability."""
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

try:
    import weave
    WEAVE_AVAILABLE = True
except ImportError:
    WEAVE_AVAILABLE = False


class WeaveTracer:
    """Wrapper for W&B Weave LLM tracing."""

    def __init__(self, project_name: str = "ground-station-network", api_key: str = ""):
        self.project_name = project_name
        self.api_key = api_key
        self.initialized = False

    def initialize(self):
        if not WEAVE_AVAILABLE:
            logger.warning("Weave not installed. Install with: pip install weave")
            return
        weave.init(self.project_name)
        self.initialized = True
        logger.info(f"Weave initialized for project '{self.project_name}'")

    def trace_call(self, func: Any) -> Any:
        """Decorate a function with Weave tracing."""
        if not WEAVE_AVAILABLE:
            return func
        return weave.op()(func)

    async def log_llm_call(self, model: str, prompt: str, response: str, duration_ms: float, metadata: dict | None = None):
        """Log an LLM call with Weave."""
        if not self.initialized:
            self.initialize()
        if not WEAVE_AVAILABLE:
            return
        try:
            call = weave.trace_call(
                "llm_call",
                inputs={"model": model, "prompt": prompt[:500], "metadata": metadata or {}},
                outputs={"response": response[:500], "duration_ms": duration_ms},
            )
            logger.debug(f"LLM call traced: {model} ({duration_ms}ms)")
        except Exception as e:
            logger.warning(f"Failed to trace LLM call: {e}")

    def trace_agent(self, agent_name: str):
        """Decorator to trace an agent call."""
        def decorator(func):
            if not WEAVE_AVAILABLE:
                return func
            op = weave.op(name=f"agent_{agent_name}")(func)
            return op
        return decorator


class WeaveDataset:
    """Wrapper for creating and managing Weave datasets for evaluation."""

    def __init__(self, name: str = "ground_station_eval"):
        self.name = name
        self.rows: list[dict[str, Any]] = []

    def add_row(self, question: str, expected: str, context: dict | None = None):
        self.rows.append({
            "question": question,
            "expected": expected,
            "context": context or {},
        })

    def publish(self):
        """Publish the dataset to Weave."""
        if not WEAVE_AVAILABLE:
            logger.info(f"[Mock] Dataset '{self.name}' with {len(self.rows)} rows ready")
            return {"name": self.name, "rows": len(self.rows)}
        try:
            dataset = weave.Dataset(name=self.name, rows=self.rows)
            weave.publish(dataset)
            logger.info(f"Dataset '{self.name}' published with {len(self.rows)} rows")
            return {"name": self.name, "rows": len(self.rows)}
        except Exception as e:
            logger.error(f"Failed to publish dataset: {e}")
            return {"error": str(e)}
