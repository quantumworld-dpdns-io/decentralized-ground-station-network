"""State management for LangGraph workflows."""
from dataclasses import dataclass, field
from typing import Any, Optional
from datetime import datetime, timezone


@dataclass
class AgentContext:
    agent_id: str
    agent_name: str
    model: str = ""
    temperature: float = 0.1
    max_tokens: int = 2048


@dataclass
class TaskState:
    task_id: str
    status: str = "pending"
    assigned_to: str = ""
    result: Any = None
    error: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None


@dataclass
class WorkflowState:
    session_id: str = ""
    messages: list[dict] = field(default_factory=list)
    tasks: dict[str, TaskState] = field(default_factory=dict)
    current_task_id: str = ""
    current_agent: str = ""
    context: dict[str, Any] = field(default_factory=dict)
    artifacts: dict[str, Any] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)
    completed: bool = False

    def add_message(self, role: str, content: str, metadata: dict | None = None):
        self.messages.append({
            "role": role,
            "content": content,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "metadata": metadata or {},
        })

    def add_task(self, task_id: str, description: str = ""):
        self.tasks[task_id] = TaskState(task_id=task_id)
        self.tasks[task_id].started_at = datetime.now(timezone.utc).isoformat()

    def complete_task(self, task_id: str, result: Any = None):
        if task_id in self.tasks:
            self.tasks[task_id].status = "completed"
            self.tasks[task_id].result = result
            self.tasks[task_id].completed_at = datetime.now(timezone.utc).isoformat()

    def fail_task(self, task_id: str, error: str):
        if task_id in self.tasks:
            self.tasks[task_id].status = "failed"
            self.tasks[task_id].error = error
            self.tasks[task_id].completed_at = datetime.now(timezone.utc).isoformat()
            self.errors.append(error)

    def get_task(self, task_id: str) -> Optional[TaskState]:
        return self.tasks.get(task_id)

    def get_errors(self) -> list[str]:
        return self.errors

    def is_complete(self) -> bool:
        return self.completed or all(t.status in ("completed", "failed") for t in self.tasks.values())
