"""Document ingestion pipeline: chunk, embed, and index ground station docs."""
import hashlib
import json
import logging
import uuid
from typing import Any

from .embeddings import EmbeddingService
from .vector_store import VectorStore

logger = logging.getLogger(__name__)


class TextChunker:
    """Split documents into overlapping chunks for embedding."""

    def __init__(self, chunk_size: int = 512, chunk_overlap: int = 64):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def chunk_text(self, text: str, metadata: dict | None = None) -> list[dict[str, Any]]:
        """Split text into overlapping chunks with metadata."""
        if not text:
            return []
        words = text.split()
        chunks = []
        for i in range(0, len(words), self.chunk_size - self.chunk_overlap):
            chunk_words = words[i:i + self.chunk_size]
            chunk_text = " ".join(chunk_words)
            chunk_id = hashlib.md5(chunk_text.encode()).hexdigest()[:12]
            chunks.append({
                "id": chunk_id,
                "text": chunk_text,
                "metadata": {
                    **(metadata or {}),
                    "chunk_index": len(chunks),
                    "total_chunks": 0,
                },
            })
        for c in chunks:
            c["metadata"]["total_chunks"] = len(chunks)
        return chunks

    def chunk_document(self, document: dict[str, Any]) -> list[dict[str, Any]]:
        """Chunk a full document with title, content, and metadata."""
        title = document.get("title", "")
        content = document.get("content", "")
        full_text = f"{title}\n\n{content}" if title else content
        metadata = document.get("metadata", {})
        return self.chunk_text(full_text, metadata)


class DocumentPipeline:
    """Pipeline for ingesting documents into the vector store."""

    def __init__(self, embedder: EmbeddingService | None = None, vector_store: VectorStore | None = None):
        self.embedder = embedder or EmbeddingService(provider="local")
        self.vector_store = vector_store or VectorStore()
        self.chunker = TextChunker()

    async def ingest_text(self, text: str, metadata: dict | None = None) -> dict[str, Any]:
        """Ingest a text string: chunk, embed, index."""
        chunks = self.chunker.chunk_text(text, metadata)
        if not chunks:
            return {"status": "empty", "chunks": 0}
        texts = [c["text"] for c in chunks]
        embeddings = await self.embedder.embed(texts)
        count = await self.vector_store.add_documents(chunks, embeddings)
        return {"status": "indexed", "chunks": count, "ids": [c["id"] for c in chunks]}

    async def ingest_document(self, document: dict[str, Any]) -> dict[str, Any]:
        """Ingest a full document dict."""
        chunks = self.chunker.chunk_document(document)
        if not chunks:
            return {"status": "empty", "chunks": 0}
        texts = [c["text"] for c in chunks]
        embeddings = await self.embedder.embed(texts)
        count = await self.vector_store.add_documents(chunks, embeddings)
        return {"status": "indexed", "chunks": count, "ids": [c["id"] for c in chunks]}

    async def ingest_batch(self, documents: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Ingest multiple documents in batch."""
        results = []
        for doc in documents:
            result = await self.ingest_document(doc)
            results.append(result)
        return results

    async def get_stats(self) -> dict[str, Any]:
        """Get pipeline and vector store statistics."""
        doc_count = await self.vector_store.count()
        return {
            "vector_store_count": doc_count,
            "chunk_size": self.chunker.chunk_size,
            "chunk_overlap": self.chunker.chunk_overlap,
            "embedding_provider": self.embedder.provider_name,
        }
