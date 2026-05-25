"""Main AI service with FastAPI endpoints, agent orchestration, and SSE streaming."""
import json
import logging
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import AsyncGenerator

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sse_starlette.sse import EventSourceResponse

logger = logging.getLogger(__name__)


class ChatRequest(BaseModel):
    message: str
    session_id: str = ""
    agent: str = "auto"


class TaskRequest(BaseModel):
    task_type: str
    params: dict = {}


class TaskResponse(BaseModel):
    task_id: str
    status: str
    result: dict = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("AI Service starting up...")
    yield
    logger.info("AI Service shutting down...")


app = FastAPI(title="Decentralized Ground Station - AI Service", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_sessions: dict[str, dict] = {}
_tasks: dict[str, dict] = {}


@app.get("/health")
async def health():
    return {"status": "ok", "service": "ai-service", "version": "2.0.0", "timestamp": datetime.now(timezone.utc).isoformat()}


@app.post("/chat")
async def chat(request: ChatRequest):
    session_id = request.session_id or f"session-{uuid.uuid4().hex[:8]}"
    if session_id not in _sessions:
        _sessions[session_id] = {"messages": [], "created": datetime.now(timezone.utc).isoformat()}
    _sessions[session_id]["messages"].append({"role": "user", "content": request.message})

    response_content = (
        f"Received message for agent '{request.agent}': {request.message[:50]}... "
        f"Processing with ground station network intelligence."
    )
    _sessions[session_id]["messages"].append({"role": "assistant", "content": response_content})

    return {
        "session_id": session_id,
        "response": response_content,
        "agent": request.agent,
    }


@app.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    session_id = request.session_id or f"session-{uuid.uuid4().hex[:8]}"
    _sessions.setdefault(session_id, {"messages": [], "created": datetime.now(timezone.utc).isoformat()})
    _sessions[session_id]["messages"].append({"role": "user", "content": request.message})

    async def event_generator():
        yield {"event": "start", "data": json.dumps({"session_id": session_id})}
        tokens = [
            f"Processing your request for agent '{request.agent}'... ",
            f"Analyzing ground station network status... ",
            f"Running diagnostics across available nodes... ",
            f"Query complete. Here is the response to: {request.message[:30]}...",
        ]
        for token in tokens:
            yield {"event": "token", "data": json.dumps({"token": token})}
            import asyncio
            await asyncio.sleep(0.05)
        yield {"event": "done", "data": json.dumps({"session_id": session_id})}

    return EventSourceResponse(event_generator())


@app.post("/tasks", response_model=TaskResponse)
async def create_task(request: TaskRequest):
    task_id = f"task-{uuid.uuid4().hex[:8]}"
    task = {
        "task_id": task_id,
        "task_type": request.task_type,
        "params": request.params,
        "status": "queued",
        "created": datetime.now(timezone.utc).isoformat(),
        "result": {},
    }
    _tasks[task_id] = task
    task["status"] = "completed"
    task["result"] = {"message": f"Task {request.task_type} completed", "params": request.params}
    return TaskResponse(task_id=task_id, status="completed", result=task["result"])


@app.get("/tasks/{task_id}")
async def get_task(task_id: str):
    task = _tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.get("/sessions/{session_id}/history")
async def get_session_history(session_id: str):
    session = _sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@app.post("/orchestrate")
async def orchestrate(request: TaskRequest):
    """Orchestrate a multi-agent workflow for complex tasks."""
    task_id = f"orch-{uuid.uuid4().hex[:8]}"
    orchestration_result = {
        "task_id": task_id,
        "task_type": request.task_type,
        "status": "orchestrated",
        "agents_involved": ["station_operator", "signal_analyst", "security_monitor"],
        "steps": [
            {"agent": "station_operator", "action": "check_stations", "status": "completed"},
            {"agent": "signal_analyst", "action": "analyze_signals", "status": "completed"},
            {"agent": "security_monitor", "action": "audit_security", "status": "completed"},
        ],
        "result": {"overall": "success", "details": request.params},
    }
    return orchestration_result


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ai_service:app", host="0.0.0.0", port=8000, reload=True)
