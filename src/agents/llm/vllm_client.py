"""vLLM integration for high-throughput LLM serving."""
import json
import logging
from typing import Any, AsyncGenerator

import httpx

logger = logging.getLogger(__name__)

try:
    from vllm import AsyncLLMEngine, AsyncEngineArgs, SamplingParams
    from vllm.entrypoints.openai.api_server import init_app
    VLLM_AVAILABLE = True
except ImportError:
    VLLM_AVAILABLE = False


class VLLMClient:
    """Client for vLLM inference server (OpenAI-compatible API)."""

    def __init__(self, base_url: str = "http://localhost:8000", model: str = "", api_key: str = "", timeout: int = 300):
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
        """Generate completion via vLLM OpenAI-compatible endpoint."""
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
            return self._stream_completion(client, payload)
        response = await client.post(f"{self.base_url}/v1/completions", json=payload)
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["text"] if data.get("choices") else ""

    async def _stream_completion(self, client: httpx.AsyncClient, payload: dict) -> AsyncGenerator[str, None]:
        async with client.stream("POST", f"{self.base_url}/v1/completions", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str.strip() == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        token = data["choices"][0].get("text", "")
                        if token:
                            yield token
                    except json.JSONDecodeError:
                        continue

    async def chat(self, messages: list[dict[str, str]], max_tokens: int = 2048, temperature: float = 0.7) -> str:
        """Chat completion via vLLM."""
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
        return data["choices"][0]["message"]["content"] if data.get("choices") else ""

    async def list_models(self) -> list[dict[str, Any]]:
        """List available models on vLLM server."""
        client = await self._get_client()
        response = await client.get(f"{self.base_url}/v1/models")
        response.raise_for_status()
        return response.json().get("data", [])

    async def is_available(self) -> bool:
        """Check if vLLM server is available."""
        try:
            client = await self._get_client()
            response = await client.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except Exception:
            return False

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None


class VLLMEngine:
    """Direct vLLM engine for in-process model serving."""

    def __init__(self, model_path: str, tensor_parallel_size: int = 1, gpu_memory_utilization: float = 0.9, max_model_len: int = 4096):
        if not VLLM_AVAILABLE:
            raise ImportError("vllm not installed. Install with: pip install vllm")
        self.engine_args = AsyncEngineArgs(
            model=model_path,
            tensor_parallel_size=tensor_parallel_size,
            gpu_memory_utilization=gpu_memory_utilization,
            max_model_len=max_model_len,
        )
        self._engine: AsyncLLMEngine | None = None

    def start(self):
        logger.info(f"Starting vLLM engine with {self.engine_args.model}")
        self._engine = AsyncLLMEngine.from_engine_args(self.engine_args)

    async def generate(self, prompt: str, max_tokens: int = 2048, temperature: float = 0.7) -> str:
        if not self._engine:
            self.start()
        sampling_params = SamplingParams(temperature=temperature, max_tokens=max_tokens)
        result = ""
        async for output in self._engine.generate(prompt, sampling_params, prompt):
            result += output.outputs[0].text
        return result

    def stop(self):
        if self._engine:
            del self._engine
            self._engine = None
            logger.info("vLLM engine stopped")
