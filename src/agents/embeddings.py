"""Embedding service with multiple provider support (OpenAI, local, BGE)."""
import logging
from typing import Any

logger = logging.getLogger(__name__)


class BaseEmbeddingProvider:
    """Base class for embedding providers."""

    def __init__(self, model_name: str, dimension: int):
        self.model_name = model_name
        self.dimension = dimension

    async def embed(self, texts: list[str]) -> list[list[float]]:
        raise NotImplementedError

    async def embed_query(self, text: str) -> list[float]:
        docs = await self.embed([text])
        return docs[0] if docs else []


class OpenAIEmbeddingProvider(BaseEmbeddingProvider):
    """OpenAI embedding provider using text-embedding-3-* models."""

    def __init__(self, model_name: str = "text-embedding-3-small", api_key: str = "", dimension: int = 1536):
        super().__init__(model_name, dimension)
        self.api_key = api_key
        self._client = None

    async def _get_client(self):
        if self._client is None:
            from openai import AsyncOpenAI
            self._client = AsyncOpenAI(api_key=self.api_key or None)
        return self._client

    async def embed(self, texts: list[str]) -> list[list[float]]:
        client = await self._get_client()
        response = await client.embeddings.create(model=self.model_name, input=texts)
        embeddings = [item.embedding for item in response.data]
        return embeddings

    async def embed_query(self, text: str) -> list[float]:
        client = await self._get_client()
        response = await client.embeddings.create(model=self.model_name, input=text)
        return response.data[0].embedding


class BGEEmbeddingProvider(BaseEmbeddingProvider):
    """BGE (BAAI General Embedding) local provider using sentence-transformers."""

    def __init__(self, model_name: str = "BAAI/bge-base-en-v1.5", dimension: int = 768):
        super().__init__(model_name, dimension)
        self._model = None

    def _load_model(self):
        if self._model is None:
            from sentence_transformers import SentenceTransformer
            self._model = SentenceTransformer(self.model_name, trust_remote_code=True)
            logger.info(f"Loaded BGE model: {self.model_name}")

    async def embed(self, texts: list[str]) -> list[list[float]]:
        self._load_model()
        embeddings = self._model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
        return embeddings.tolist()


class LocalEmbeddingProvider(BaseEmbeddingProvider):
    """Local embedding provider using a lightweight ONNX model."""

    def __init__(self, model_name: str = "all-MiniLM-L6-v2", dimension: int = 384):
        super().__init__(model_name, dimension)
        self._model = None

    def _load_model(self):
        if self._model is None:
            from sentence_transformers import SentenceTransformer
            self._model = SentenceTransformer(self.model_name)
            logger.info(f"Loaded local model: {self.model_name}")

    async def embed(self, texts: list[str]) -> list[list[float]]:
        self._load_model()
        embeddings = self._model.encode(texts, show_progress_bar=False)
        return embeddings.tolist()


class EmbeddingService:
    """Unified embedding service that selects the best available provider."""

    def __init__(self, provider: str = "local", **kwargs):
        self.provider_name = provider
        self._provider: BaseEmbeddingProvider | None = None
        self._kwargs = kwargs

    async def _get_provider(self) -> BaseEmbeddingProvider:
        if self._provider is not None:
            return self._provider
        if self.provider_name == "openai":
            self._provider = OpenAIEmbeddingProvider(**self._kwargs)
        elif self.provider_name == "bge":
            self._provider = BGEEmbeddingProvider(**self._kwargs)
        else:
            self._provider = LocalEmbeddingProvider(**self._kwargs)
        logger.info(f"Using embedding provider: {self.provider_name} ({self._provider.model_name})")
        return self._provider

    async def embed(self, texts: list[str]) -> list[list[float]]:
        provider = await self._get_provider()
        return await provider.embed(texts)

    async def embed_query(self, text: str) -> list[float]:
        provider = await self._get_provider()
        return await provider.embed_query(text)

    @property
    def dimension(self) -> int:
        if self._provider:
            return self._provider.dimension
        return self._kwargs.get("dimension", 384)
