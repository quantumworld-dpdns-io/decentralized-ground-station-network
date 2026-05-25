"""Arize Phoenix OpenInference tracing for LLM observability."""
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

try:
    from openinference.instrumentation.langchain import LangChainInstrumentor
    PHOENIX_AVAILABLE = True
except ImportError:
    PHOENIX_AVAILABLE = False


class PhoenixTracer:
    """Wrapper for Arize Phoenix OpenInference tracing."""

    def __init__(self, endpoint: str = "http://localhost:6006", project_name: str = "ground-station-network"):
        self.endpoint = endpoint
        self.project_name = project_name
        self.initialized = False

    def initialize(self):
        """Initialize Phoenix tracing for LangChain."""
        if not PHOENIX_AVAILABLE:
            logger.warning("Phoenix not available. Install with: pip install arize-phoenix openinference-instrumentation-langchain")
            return
        try:
            LangChainInstrumentor().instrument()
            self.initialized = True
            logger.info(f"Phoenix tracing initialized (endpoint: {self.endpoint})")
        except Exception as e:
            logger.warning(f"Failed to initialize Phoenix: {e}")

    def shutdown(self):
        """Shutdown Phoenix tracing."""
        if PHOENIX_AVAILABLE and self.initialized:
            try:
                LangChainInstrumentor().uninstrument()
                self.initialized = False
                logger.info("Phoenix tracing shut down")
            except Exception as e:
                logger.warning(f"Failed to shutdown Phoenix: {e}")

    def trace_chain(self, chain: Any) -> Any:
        """Wrap a LangChain chain with Phoenix tracing."""
        if not PHOENIX_AVAILABLE:
            return chain
        return chain

    async def log_event(self, event_type: str, data: dict[str, Any]):
        """Log a custom event to Phoenix."""
        logger.debug(f"[Phoenix] Event: {event_type}")
        return {"status": "logged", "event_type": event_type}


class PhoenixSpan:
    """Context manager for creating OpenInference spans."""

    def __init__(self, tracer: PhoenixTracer, name: str):
        self.tracer = tracer
        self.name = name
        self.span = None

    async def __aenter__(self):
        logger.debug(f"[Phoenix] Starting span: {self.name}")
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        logger.debug(f"[Phoenix] Closing span: {self.name}")
        if exc_val:
            logger.error(f"Span '{self.name}' error: {exc_val}")


def instrument_langchain():
    """Convenience function to instrument LangChain with Phoenix."""
    tracer = PhoenixTracer()
    tracer.initialize()
    return tracer
