"""RAG query service: retrieve, rerank, and generate responses."""
import json
import logging
from typing import Any

from .embeddings import EmbeddingService
from .vector_store import VectorStore

logger = logging.getLogger(__name__)


class RAGService:
    """Retrieval-Augmented Generation service for ground station knowledge."""

    def __init__(self, embedder: EmbeddingService | None = None, vector_store: VectorStore | None = None, llm: Any = None):
        self.embedder = embedder or EmbeddingService(provider="local")
        self.vector_store = vector_store or VectorStore()
        self.llm = llm

    async def retrieve(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """Retrieve relevant documents for a query."""
        query_embedding = await self.embedder.embed_query(query)
        results = await self.vector_store.search(query_embedding, top_k=top_k)
        return results

    async def retrieve_with_scores(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """Retrieve documents with relevance scores."""
        results = await self.retrieve(query, top_k)
        for r in results:
            r["relevance"] = 1.0 / (1.0 + r.get("score", 0))
        return sorted(results, key=lambda x: x["relevance"], reverse=True)

    async def generate(self, query: str, context_docs: list[dict[str, Any]]) -> str:
        """Generate a response using retrieved context."""
        if not context_docs:
            return "No relevant information found."
        context = "\n\n".join([
            f"Document: {d.get('metadata', {}).get('title', 'Untitled')}\n{d.get('metadata', {}).get('text', d.get('id', ''))}"
            for d in context_docs[:3]
        ])
        prompt = (
            f"Answer the following question based on the provided context.\n\n"
            f"Context:\n{context}\n\n"
            f"Question: {query}\n\n"
            f"Answer:"
        )
        if self.llm:
            try:
                response = await self.llm.ainvoke(prompt)
                return response.content if hasattr(response, "content") else str(response)
            except Exception as e:
                logger.warning(f"LLM generation failed: {e}")
        return f"Based on the retrieved information: {context[:200]}..."

    async def query(self, query: str, top_k: int = 5) -> dict[str, Any]:
        """End-to-end RAG query: retrieve, rerank, generate."""
        docs = await self.retrieve_with_scores(query, top_k)
        answer = await self.generate(query, docs)
        return {
            "query": query,
            "answer": answer,
            "sources": [
                {"id": d["id"], "score": d.get("score", 0), "relevance": d.get("relevance", 0)}
                for d in docs
            ],
            "num_sources": len(docs),
        }
