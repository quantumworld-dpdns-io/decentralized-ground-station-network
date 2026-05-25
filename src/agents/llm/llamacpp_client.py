"""llama.cpp Python bindings client for local inference."""
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

try:
    from llama_cpp import Llama
    LLAMA_CPP_AVAILABLE = True
except ImportError:
    LLAMA_CPP_AVAILABLE = False


class LlamaCPPClient:
    """Client for llama.cpp local model inference."""

    def __init__(self, model_path: str, n_ctx: int = 4096, n_threads: int = 8, n_gpu_layers: int = 0, verbose: bool = False):
        self.model_path = model_path
        self.n_ctx = n_ctx
        self.n_threads = n_threads
        self.n_gpu_layers = n_gpu_layers
        self.verbose = verbose
        self._model = None

    def _load(self):
        if self._model is None:
            if not LLAMA_CPP_AVAILABLE:
                raise ImportError("llama-cpp-python not installed. Install with: pip install llama-cpp-python")
            self._model = Llama(
                model_path=self.model_path,
                n_ctx=self.n_ctx,
                n_threads=self.n_threads,
                n_gpu_layers=self.n_gpu_layers,
                verbose=self.verbose,
            )
            logger.info(f"Loaded llama.cpp model from {self.model_path}")

    def generate(self, prompt: str, max_tokens: int = 2048, temperature: float = 0.7, top_p: float = 0.9) -> str:
        """Generate text from a prompt."""
        self._load()
        output = self._model(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
            echo=False,
        )
        return output["choices"][0]["text"] if output.get("choices") else ""

    def chat(self, messages: list[dict[str, str]], max_tokens: int = 2048, temperature: float = 0.7) -> str:
        """Generate a chat completion."""
        self._load()
        prompt = self._format_chat_prompt(messages)
        return self.generate(prompt, max_tokens=max_tokens, temperature=temperature)

    def _format_chat_prompt(self, messages: list[dict[str, str]]) -> str:
        """Format messages into a prompt string."""
        prompt = ""
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "system":
                prompt += f"<|system|>\n{content}\n"
            elif role == "user":
                prompt += f"<|user|>\n{content}\n"
            elif role == "assistant":
                prompt += f"<|assistant|>\n{content}\n"
        prompt += "<|assistant|>\n"
        return prompt

    def embed(self, text: str) -> list[float]:
        """Generate embeddings for a text."""
        self._load()
        embedding = self._model.embed(text)
        return embedding.tolist() if hasattr(embedding, "tolist") else embedding

    def tokenize(self, text: str) -> list[int]:
        """Tokenize a text string."""
        self._load()
        return self._model.tokenize(text.encode("utf-8"))

    def detokenize(self, tokens: list[int]) -> str:
        """Detokenize tokens back to text."""
        self._load()
        return self._model.detokenize(tokens).decode("utf-8", errors="replace")

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    def close(self):
        if self._model is not None:
            self._model.close()
            self._model = None
            logger.info("llama.cpp model unloaded")
