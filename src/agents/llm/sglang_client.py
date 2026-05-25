"""SGLang client for structured generation and high-throughput inference."""
import json
import logging
from typing import Any, AsyncGenerator

import httpx

logger = logging.getLogger(__name__)

try:
    import sglang as sgl
    from sglang import Runtime
    SGLANG_AVAILABLE = True
except ImportError:
    SGLANG_AVAILABLE = False


class SGLangClient:
    """Client for SGLang inference server (OpenAI-compatible API)."""

    def __init__(self, base_url: str = "http://localhost:30000", model: str = "", api_key: str = "", timeout: int = 300):
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.api_key = api_key
        self.timeout = timeout
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            headers = {}
            if self.api_key:
                headers["Authorization"] = f"Bearer {self.api_key}"
            self._client = httpx.AsyncClient(timeout=self.timeout, headers=headers)
        return self._client

    async def generate(self, prompt: str, max_tokens: int = 2048, temperature: float = 0.7, top_p: float = 0.9, stream: bool = False) -> str | AsyncGenerator[str, None]:
        """Generate completion via SGLang API."""
        client = await self._get_client()
        payload = {
            "model": self.model or "default",
            "prompt": prompt,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "top_p": top_p,
            "stream": stream,
        }
        if stream:
            return self._stream_generate(client, payload)
        response = await client.post(f"{self.base_url}/v1/completions", json=payload)
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["text"] if data.get("choices") else ""

    async def _stream_generate(self, client: httpx.AsyncClient, payload: dict) -> AsyncGenerator[str, None]:
        async with client.stream("POST", f"{self.base_url}/v1/completions", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str.strip() == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        choices = data.get("choices", [])
                        if choices:
                            text = choices[0].get("text", "")
                            if text:
                                yield text
                    except json.JSONDecodeError:
                        continue

    async def chat(self, messages: list[dict[str, str]], max_tokens: int = 2048, temperature: float = 0.7) -> str:
        """Chat completion via SGLang."""
        client = await self._get_client()
        payload = {
            "model": self.model or "default",
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        response = await client.post(f"{self.base_url}/v1/chat/completions", json=payload)
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]

    async def generate_structured(self, prompt: str, json_schema: dict[str, Any], max_tokens: int = 4096, temperature: float = 0.1) -> dict[str, Any]:
        """Generate structured JSON output following a schema using SGLang grammar."""
        client = await self._get_client()
        payload = {
            "model": self.model or "default",
            "prompt": prompt,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "response_format": {"type": "json_object", "schema": json_schema},
            "grammar": json_schema,
        }
        response = await client.post(f"{self.base_url}/v1/completions", json=payload)
        response.raise_for_status()
        data = response.json()
        text = data["choices"][0]["text"] if data.get("choices") else "{}"
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {"raw": text, "error": "Failed to parse JSON"}

    async def is_available(self) -> bool:
        try:
            client = await self._get_client()
            response = await client.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except Exception:
            return False

    async def get_server_info(self) -> dict[str, Any]:
        client = await self._get_client()
        response = await client.get(f"{self.base_url}/v1/models")
        response.raise_for_status()
        return response.json()

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None
