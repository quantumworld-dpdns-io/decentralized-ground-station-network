"""LangChain integration with custom tools, retrievers, and chains."""
import json
import logging
from typing import Any

from langchain.tools import BaseTool, StructuredTool
from langchain_core.runnables import RunnablePassthrough
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


class StationQueryInput(BaseModel):
    station_id: str = Field(description="Ground station ID to query")


class SignalAnalysisInput(BaseModel):
    signal_data: str = Field(description="Base64-encoded IQ signal data")
    sampling_rate: float = Field(description="Sampling rate in Hz")


def create_station_status_tool() -> BaseTool:
    """Create a LangChain tool for checking ground station status."""
    def _get_status(station_id: str) -> str:
        stations = {
            "gs-1": {"name": "McMurdo", "status": "online", "antennas": 2},
            "gs-2": {"name": "Svalbard", "status": "online", "antennas": 3},
            "gs-3": {"name": "Kourou", "status": "maintenance", "antennas": 2},
        }
        station = stations.get(station_id, {})
        return json.dumps(station)

    return StructuredTool.from_function(
        func=_get_status,
        name="station_status",
        description="Get the operational status of a ground station by ID",
        args_schema=StationQueryInput,
    )


def create_schedule_tool() -> BaseTool:
    """Create a LangChain tool for looking up ground station schedules."""
    def _get_schedule(station_id: str, date: str = "") -> str:
        if not date:
            from datetime import date as dt_date
            date = dt_date.today().isoformat()
        passes = [
            {"satellite": "SAT-001", "aos": f"{date}T10:00:00Z", "los": f"{date}T10:15:00Z", "elevation": 45.0},
            {"satellite": "SAT-042", "aos": f"{date}T14:30:00Z", "los": f"{date}T14:45:00Z", "elevation": 82.0},
        ]
        return json.dumps({"station": station_id, "date": date, "passes": passes})

    return StructuredTool.from_function(
        func=_get_schedule,
        name="schedule_lookup",
        description="Look up the satellite pass schedule for a ground station",
        args_schema=type("ScheduleInput", (BaseModel,), {
            "station_id": str,
            "date": (str, Field(default="", description="Date in YYYY-MM-DD format")),
        }),
    )


def create_ground_station_chain(llm: Any) -> Any:
    """Create a LangChain chain for ground station Q&A."""
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a ground station operations assistant. Answer questions about "
                   "satellite ground stations, their status, schedules, and capabilities. "
                   "Use the available tools to look up real information."),
        ("human", "{question}"),
    ])
    tools = [create_station_status_tool(), create_schedule_tool()]
    llm_with_tools = llm.bind_tools(tools)
    chain = prompt | llm_with_tools | StrOutputParser()
    return chain


async def run_chain(chain: Any, question: str) -> str:
    """Run a LangChain with a user question."""
    result = await chain.ainvoke({"question": question})
    return result
