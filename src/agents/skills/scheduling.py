"""Scheduling skill: optimize, assign, and resolve conflicts for satellite passes."""
import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Any

logger = logging.getLogger(__name__)


def optimize_schedule(station_id: str, passes: list[dict[str, Any]]) -> dict[str, Any]:
    """Optimize a schedule of passes to maximize throughput and minimize gaps."""
    sorted_passes = sorted(passes, key=lambda p: p.get("aos", ""))
    optimized = []
    conflicts = []

    for i, p in enumerate(sorted_passes):
        p_start = datetime.fromisoformat(p["aos"].replace("Z", "+00:00"))
        p_end = datetime.fromisoformat(p["los"].replace("Z", "+00:00"))
        conflict = False

        for existing in optimized:
            e_start = datetime.fromisoformat(existing["aos"].replace("Z", "+00:00"))
            e_end = datetime.fromisoformat(existing["los"].replace("Z", "+00:00"))
            if p_start < e_end and p_end > e_start:
                conflicts.append({
                    "pass_a": p["satellite"],
                    "pass_b": existing["satellite"],
                    "overlap_start": max(p_start, e_start).isoformat(),
                    "overlap_end": min(p_end, e_end).isoformat(),
                })
                conflict = True
                break

        if not conflict:
            optimized.append(p)

    total_time = sum(
        (datetime.fromisoformat(p["los"].replace("Z", "+00:00")) -
         datetime.fromisoformat(p["aos"].replace("Z", "+00:00"))).total_seconds() / 60
        for p in optimized
    )

    return {
        "station_id": station_id,
        "original_passes": len(passes),
        "scheduled_passes": len(optimized),
        "conflicts_found": len(conflicts),
        "conflicts": conflicts,
        "schedule": optimized,
        "total_pass_time_minutes": round(total_time, 1),
    }


def assign_pass(satellite_id: str, station_id: str, aos: str, los: str, priority: str = "normal") -> dict[str, Any]:
    """Assign a satellite pass to a ground station."""
    assignment = {
        "assignment_id": f"asn-{satellite_id}-{station_id}",
        "satellite_id": satellite_id,
        "station_id": station_id,
        "aos": aos,
        "los": los,
        "priority": priority,
        "duration_minutes": round(
            (datetime.fromisoformat(los.replace("Z", "+00:00")) -
             datetime.fromisoformat(aos.replace("Z", "+00:00"))).total_seconds() / 60, 1
        ),
        "status": "scheduled",
        "assigned_at": datetime.now(timezone.utc).isoformat(),
    }
    logger.info(f"Pass assigned: {satellite_id} -> {station_id} ({aos} to {los})")
    return assignment


def resolve_conflicts(assignments: list[dict[str, Any]]) -> dict[str, Any]:
    """Resolve scheduling conflicts between assignments."""
    resolved = []
    conflicts_resolved = 0
    priority_order = {"emergency": 0, "high": 1, "normal": 2, "low": 3}
    sorted_assignments = sorted(
        assignments,
        key=lambda a: (priority_order.get(a.get("priority", "normal"), 99), a.get("aos", "")),
    )

    for assignment in sorted_assignments:
        a_start = datetime.fromisoformat(assignment["aos"].replace("Z", "+00:00"))
        a_end = datetime.fromisoformat(assignment["los"].replace("Z", "+00:00"))
        conflict = False

        for r in resolved:
            r_start = datetime.fromisoformat(r["aos"].replace("Z", "+00:00"))
            r_end = datetime.fromisoformat(r["los"].replace("Z", "+00:00"))
            if a_start < r_end and a_end > r_start:
                conflict = True
                conflicts_resolved += 1
                logger.info(f"Conflict resolved: {assignment['satellite_id']} deferred in favor of {r['satellite_id']}")
                break

        if not conflict:
            resolved.append(assignment)

    return {
        "total_input": len(assignments),
        "total_scheduled": len(resolved),
        "conflicts_resolved": conflicts_resolved,
        "schedule": resolved,
    }
