"""Ollama API client for local model inference."""
import json
import logging
from typing import Any, AsyncGenerator

import httpx

logger = logging.getLogger(__name__)


class OllamaClient:
    """Client for Ollama local model inference."""

    def __init__(self, base_url: str = "http://localhost:11434", model: str = "llama3.1:8b", timeout: int = 120):
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout = timeout
        self._http_client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=self.timeout)
        return self._http_client

    async def generate(self, prompt: str, system_prompt: str = "", temperature: float = 0.7, max_tokens: int = 2048, stream: bool = False) -> str | AsyncGenerator[str, None]:
        """Generate a response from the model."""
        client = await self._get_client()
        payload = {
            "model": self.model,
            "prompt": prompt,
            "system": system_prompt,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream,
        }
        if stream:
            return self._stream_generate(client, payload)
        response = await client.post(f"{self.base_url}/api/generate", json=payload)
        response.raise_for_status()
        result = response.json()
        return result.get("response", "")

    async def _stream_generate(self, client: httpx.AsyncClient, payload: dict) -> AsyncGenerator[str, None]:
        async with client.stream("POST", f"{self.base_url}/api/generate", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line:
                    try:
                        data = json.loads(line)
                        token = data.get("response", "")
                        if token:
                            yield token
                        if data.get("done", False):
                            break
                    except json.JSONDecodeError:
                        continue

    async def chat(self, messages: list[dict[str, str]], model: str = "", temperature: float = 0.7) -> str:
        """Chat completion using Ollama."""
        client = await self._get_client()
        payload = {
            "model": model or self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": False,
        }
        response = await client.post(f"{self.base_url}/api/chat", json=payload)
        response.raise_for_status()
        result = response.json()
        return result.get("message", {}).get("content", "")

    async def list_models(self) -> list[dict[str, Any]]:
        """List available models in Ollama."""
        client = await self._get_client()
        response = await client.get(f"{self.base_url}/api/tags")
        response.raise_for_status()
        return response.json().get("models", [])

    async def pull_model(self, model_name: str) -> bool:
        """Pull a model to the local Ollama instance."""
        client = await self._get_client()
        response = await client.post(f"{self.base_url}/api/pull", json={"name": model_name})
        response.raise_for_status()
        logger.info(f"Pulled model: {model_name}")
        return True

    async def is_available(self) -> bool:
        """Check if the Ollama server is available."""
        try:
            client = await self._get_client()
            response = await client.get(f"{self.base_url}/api/tags", timeout=5)
            return response.status_code == 200
        except Exception:
            return False

    async def close(self):
        if self._http_client:
            await self._http_client.aclose()
            self._http_client = None
