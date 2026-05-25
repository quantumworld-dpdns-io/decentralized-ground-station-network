"""Auto-select best available model based on task and available resources."""
import json
import logging
from typing import Any

from .ollama_client import OllamaClient

logger = logging.getLogger(__name__)


class ModelSelector:
    """Auto-select the best available model for a given task."""

    def __init__(self):
        self._ollama = OllamaClient()
        self._available_models: dict[str, dict[str, Any]] = {}
        self._cache_valid = False

    MODEL_REGISTRY: dict[str, list[dict[str, Any]]] = {
        "reasoning": [
            {"name": "gpt-4o", "provider": "openai", "capabilities": ["reasoning", "tools", "vision"], "max_tokens": 16384},
            {"name": "claude-3.5-sonnet", "provider": "anthropic", "capabilities": ["reasoning", "tools", "vision"], "max_tokens": 8192},
            {"name": "llama3.1:70b", "provider": "ollama", "capabilities": ["reasoning", "tools"], "max_tokens": 8192},
        ],
        "code": [
            {"name": "gpt-4o", "provider": "openai", "capabilities": ["code", "reasoning"], "max_tokens": 16384},
            {"name": "codellama:34b", "provider": "ollama", "capabilities": ["code"], "max_tokens": 8192},
            {"name": "deepseek-coder:33b", "provider": "ollama", "capabilities": ["code"], "max_tokens": 8192},
        ],
        "fast": [
            {"name": "gpt-4o-mini", "provider": "openai", "capabilities": ["chat", "tools"], "max_tokens": 16384},
            {"name": "llama3.1:8b", "provider": "ollama", "capabilities": ["chat"], "max_tokens": 4096},
            {"name": "mistral:7b", "provider": "ollama", "capabilities": ["chat"], "max_tokens": 4096},
        ],
        "embedding": [
            {"name": "text-embedding-3-small", "provider": "openai", "dimension": 1536},
            {"name": "BAAI/bge-base-en-v1.5", "provider": "local", "dimension": 768},
            {"name": "all-MiniLM-L6-v2", "provider": "local", "dimension": 384},
        ],
    }

    async def discover_models(self) -> dict[str, Any]:
        """Discover available models from all providers."""
        if self._cache_valid:
            return self._available_models

        available = {"ollama": [], "openai": True, "anthropic": False}

        try:
            ollama_models = await self._ollama.list_models()
            available["ollama"] = [m["name"] for m in ollama_models]
        except Exception:
            available["ollama"] = []

        self._available_models = available
        self._cache_valid = True
        logger.info(f"Discovered models: {len(available['ollama'])} Ollama, OpenAI: {available['openai']}")
        return available

    async def select_model(self, task_type: str = "fast", preferred_provider: str = "") -> dict[str, Any]:
        """Select the best model for a task type."""
        await self.discover_models()
        candidates = self.MODEL_REGISTRY.get(task_type, self.MODEL_REGISTRY["fast"])

        if preferred_provider:
            candidates = [c for c in candidates if c["provider"] == preferred_provider]

        for candidate in candidates:
            if candidate["provider"] == "ollama":
                if candidate["name"] in self._available_models.get("ollama", []):
                    return candidate
            elif candidate["provider"] == "openai" and self._available_models.get("openai"):
                return candidate
            elif candidate["provider"] == "local":
                return candidate

        return candidates[-1] if candidates else {"name": "gpt-4o-mini", "provider": "openai", "max_tokens": 16384}

    async def select_embedding_model(self) -> dict[str, Any]:
        """Select the best available embedding model."""
        try:
            await self.discover_models()
        except Exception:
            pass
        candidates = self.MODEL_REGISTRY["embedding"]
        for c in candidates:
            if c["provider"] == "openai" and self._available_models.get("openai"):
                return c
        return candidates[-1]

    async def is_available(self, model_name: str) -> bool:
        """Check if a specific model is available."""
        await self.discover_models()
        all_models = set(self._available_models.get("ollama", []))
        all_models.add("gpt-4o")
        all_models.add("gpt-4o-mini")
        all_models.add("claude-3.5-sonnet")
        return model_name in all_models

    def invalidate_cache(self):
        self._cache_valid = False
