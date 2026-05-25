"""Flower federated learning server with FedAvg strategy."""
import json
import logging
from typing import Any

import flwr as fl
from flwr.server.strategy import FedAvg

logger = logging.getLogger(__name__)


def create_strategy(
    fraction_fit: float = 1.0,
    fraction_evaluate: float = 1.0,
    min_fit_clients: int = 2,
    min_evaluate_clients: int = 2,
    min_available_clients: int = 2,
    initial_parameters: Any = None,
) -> FedAvg:
    """Create a FedAvg strategy for federated signal classification."""
    return FedAvg(
        fraction_fit=fraction_fit,
        fraction_evaluate=fraction_evaluate,
        min_fit_clients=min_fit_clients,
        min_evaluate_clients=min_evaluate_clients,
        min_available_clients=min_available_clients,
        initial_parameters=initial_parameters,
        on_fit_config_fn=lambda rnd: {
            "local_epochs": 5,
            "batch_size": 32,
            "current_round": rnd,
        },
        on_evaluate_config_fn=lambda rnd: {
            "batch_size": 32,
            "current_round": rnd,
        },
    )


def start_server(
    num_rounds: int = 10,
    server_address: str = "0.0.0.0:8080",
    config: dict[str, Any] | None = None,
) -> fl.server.Server:
    """Start the Flower federated learning server."""
    cfg = config or {}
    strategy = create_strategy(
        fraction_fit=cfg.get("fraction_fit", 1.0),
        fraction_evaluate=cfg.get("fraction_evaluate", 1.0),
        min_fit_clients=cfg.get("min_fit_clients", 2),
        min_evaluate_clients=cfg.get("min_evaluate_clients", 2),
        min_available_clients=cfg.get("min_available_clients", 2),
    )
    history = fl.server.start_server(
        server_address=server_address,
        config=fl.server.ServerConfig(num_rounds=num_rounds),
        strategy=strategy,
    )
    logger.info(f"Federated learning completed. Accuracy: {history.metrics_centralized.get('accuracy', [])}")
    return history


def save_history(history: fl.server.ServerState, path: str = "federated_history.json"):
    """Save training history to a JSON file."""
    results = {
        "losses_distributed": history.losses_distributed if hasattr(history, "losses_distributed") else [],
        "metrics_distributed_fit": history.metrics_distributed_fit if hasattr(history, "metrics_distributed_fit") else {},
    }
    with open(path, "w") as f:
        json.dump(results, f, indent=2)
    logger.info(f"History saved to {path}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    start_server(num_rounds=5)
