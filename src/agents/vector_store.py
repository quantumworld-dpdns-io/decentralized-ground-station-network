"""Vector store abstraction supporting Chroma, Qdrant, and Weaviate backends."""
import json
import logging
from typing import Any

logger = logging.getLogger(__name__)


class VectorStoreBackend:
    """Abstract base for vector store backends."""

    def __init__(self, collection_name: str, dimension: int):
        self.collection_name = collection_name
        self.dimension = dimension

    async def add(self, ids: list[str], embeddings: list[list[float]], metadatas: list[dict] | None = None) -> int:
        raise NotImplementedError

    async def search(self, query_embedding: list[float], top_k: int = 10) -> list[dict]:
        raise NotImplementedError

    async def delete(self, ids: list[str]) -> bool:
        raise NotImplementedError

    async def count(self) -> int:
        raise NotImplementedError


class ChromaBackend(VectorStoreBackend):
    """ChromaDB vector store backend."""

    def __init__(self, collection_name: str, dimension: int, persist_dir: str = "./chroma_db"):
        super().__init__(collection_name, dimension)
        self.persist_dir = persist_dir
        self._collection = None

    def _get_collection(self):
        if self._collection is not None:
            return self._collection
        import chromadb
        client = chromadb.PersistentClient(path=self.persist_dir)
        try:
            self._collection = client.get_collection(self.collection_name)
        except ValueError:
            self._collection = client.create_collection(self.collection_name)
        return self._collection

    async def add(self, ids: list[str], embeddings: list[list[float]], metadatas: list[dict] | None = None) -> int:
        collection = self._get_collection()
        collection.add(ids=ids, embeddings=embeddings, metadatas=metadatas or [{}] * len(ids))
        return len(ids)

    async def search(self, query_embedding: list[float], top_k: int = 10) -> list[dict]:
        collection = self._get_collection()
        results = collection.query(query_embeddings=[query_embedding], n_results=top_k)
        items = []
        for i in range(len(results["ids"][0])):
            items.append({
                "id": results["ids"][0][i],
                "score": results["distances"][0][i] if results.get("distances") else 0,
                "metadata": results["metadatas"][0][i] if results.get("metadatas") else {},
            })
        return items

    async def delete(self, ids: list[str]) -> bool:
        collection = self._get_collection()
        collection.delete(ids=ids)
        return True

    async def count(self) -> int:
        collection = self._get_collection()
        return collection.count()


class QdrantBackend(VectorStoreBackend):
    """Qdrant vector store backend."""

    def __init__(self, collection_name: str, dimension: int, url: str = "http://localhost:6333"):
        super().__init__(collection_name, dimension)
        self.url = url
        self._client = None

    def _get_client(self):
        if self._client is not None:
            return self._client
        from qdrant_client import QdrantClient
        from qdrant_client.http.models import Distance, VectorParams
        self._client = QdrantClient(url=self.url)
        try:
            self._client.get_collection(self.collection_name)
        except Exception:
            self._client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(size=self.dimension, distance=Distance.COSINE),
            )
        return self._client

    async def add(self, ids: list[str], embeddings: list[list[float]], metadatas: list[dict] | None = None) -> int:
        from qdrant_client.http.models import PointStruct
        client = self._get_client()
        points = [
            PointStruct(id=idx, vector=embeddings[idx], payload=metadatas[idx] if metadatas else {})
            for idx in range(len(ids))
        ]
        client.upsert(collection_name=self.collection_name, points=points)
        return len(ids)

    async def search(self, query_embedding: list[float], top_k: int = 10) -> list[dict]:
        client = self._get_client()
        results = client.search(collection_name=self.collection_name, query_vector=query_embedding, limit=top_k)
        return [{"id": str(r.id), "score": r.score, "metadata": r.payload or {}} for r in results]

    async def delete(self, ids: list[str]) -> bool:
        client = self._get_client()
        client.delete(collection_name=self.collection_name, points_selector=ids)
        return True

    async def count(self) -> int:
        client = self._get_client()
        result = client.count(collection_name=self.collection_name)
        return result.count


class VectorStoreFactory:
    """Factory for creating vector store backends."""

    @staticmethod
    def create(backend: str, collection_name: str, dimension: int, **kwargs) -> VectorStoreBackend:
        if backend == "chroma":
            return ChromaBackend(collection_name, dimension, **kwargs)
        elif backend == "qdrant":
            return QdrantBackend(collection_name, dimension, **kwargs)
        else:
            raise ValueError(f"Unknown vector store backend: {backend}")


class VectorStore:
    """High-level vector store interface."""

    def __init__(self, backend: str = "chroma", collection_name: str = "ground_station_docs", dimension: int = 384, **kwargs):
        self._backend = VectorStoreFactory.create(backend, collection_name, dimension, **kwargs)
        logger.info(f"VectorStore initialized with backend={backend}, collection={collection_name}, dim={dimension}")

    async def add_documents(self, documents: list[dict[str, Any]], embeddings: list[list[float]]) -> int:
        ids = [doc.get("id", f"doc-{i}") for i, doc in enumerate(documents)]
        metadatas = [doc.get("metadata", {}) for doc in documents]
        return await self._backend.add(ids, embeddings, metadatas)

    async def search(self, query_embedding: list[float], top_k: int = 10) -> list[dict]:
        return await self._backend.search(query_embedding, top_k)

    async def delete_documents(self, ids: list[str]) -> bool:
        return await self._backend.delete(ids)

    async def count(self) -> int:
        return await self._backend.count()
