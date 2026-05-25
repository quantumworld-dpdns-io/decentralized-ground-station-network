"""Flower client for per-station model training on signal data."""
import json
import logging
from typing import Any

import flwr as fl
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

from .model import SignalCNN, get_parameters, set_parameters

logger = logging.getLogger(__name__)


class GroundStationClient(fl.client.NumPyClient):
    """Flower client that trains on local ground station signal data."""

    def __init__(self, station_id: str, X_train: torch.Tensor, y_train: torch.Tensor,
                 X_val: torch.Tensor | None = None, y_val: torch.Tensor | None = None,
                 num_classes: int = 11, learning_rate: float = 0.001, batch_size: int = 32):
        self.station_id = station_id
        self.model = SignalCNN(num_classes=num_classes)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.criterion = nn.CrossEntropyLoss()
        self.optimizer = optim.Adam(self.model.parameters(), lr=learning_rate)
        self.batch_size = batch_size

        self.train_loader = DataLoader(TensorDataset(X_train, y_train), batch_size=batch_size, shuffle=True)
        self.val_loader = None
        if X_val is not None and y_val is not None:
            self.val_loader = DataLoader(TensorDataset(X_val, y_val), batch_size=batch_size)

    def get_parameters(self, config: dict[str, Any] | None = None) -> list[bytes]:
        return [p.cpu().numpy() for p in self.model.parameters()]

    def fit(self, parameters: list[bytes], config: dict[str, Any]) -> tuple[list[bytes], int, dict]:
        set_parameters(self.model, [torch.tensor(p) for p in parameters])
        self.model.train()
        total_loss = 0.0
        for epoch in range(config.get("local_epochs", 1)):
            for batch_X, batch_y in self.train_loader:
                batch_X, batch_y = batch_X.to(self.device), batch_y.to(self.device)
                self.optimizer.zero_grad()
                outputs = self.model(batch_X)
                loss = self.criterion(outputs, batch_y)
                loss.backward()
                self.optimizer.step()
                total_loss += loss.item()
        avg_loss = total_loss / max(len(self.train_loader), 1)
        logger.info(f"Station {self.station_id} fit complete. Loss: {avg_loss:.4f}")
        return self.get_parameters(), len(self.train_loader.dataset), {"loss": avg_loss}

    def evaluate(self, parameters: list[bytes], config: dict[str, Any]) -> tuple[float, int, dict]:
        set_parameters(self.model, [torch.tensor(p) for p in parameters])
        if self.val_loader is None:
            return 0.0, 0, {}
        self.model.eval()
        total_loss = 0.0
        correct = 0
        total = 0
        with torch.no_grad():
            for batch_X, batch_y in self.val_loader:
                batch_X, batch_y = batch_X.to(self.device), batch_y.to(self.device)
                outputs = self.model(batch_X)
                loss = self.criterion(outputs, batch_y)
                total_loss += loss.item()
                _, predicted = torch.max(outputs, 1)
                total += batch_y.size(0)
                correct += (predicted == batch_y).sum().item()
        accuracy = correct / max(total, 1)
        avg_loss = total_loss / max(len(self.val_loader), 1)
        logger.info(f"Station {self.station_id} eval: loss={avg_loss:.4f}, acc={accuracy:.4f}")
        return float(avg_loss), len(self.val_loader.dataset), {"accuracy": float(accuracy)}


def create_client(station_id: str, data: dict[str, Any]) -> GroundStationClient:
    """Create a Flower client from pre-loaded data."""
    X_train = torch.tensor(data["X_train"], dtype=torch.float32)
    y_train = torch.tensor(data["y_train"], dtype=torch.long)
    X_val = torch.tensor(data.get("X_val", []), dtype=torch.float32) if data.get("X_val") else None
    y_val = torch.tensor(data.get("y_val", []), dtype=torch.long) if data.get("y_val") else None
    return GroundStationClient(
        station_id=station_id,
        X_train=X_train,
        y_train=y_train,
        X_val=X_val,
        y_val=y_val,
        num_classes=data.get("num_classes", 11),
        learning_rate=data.get("learning_rate", 0.001),
        batch_size=data.get("batch_size", 32),
    )


def start_client(station_id: str, server_address: str = "127.0.0.1:8080", data: dict | None = None):
    """Start a Flower client for a ground station."""
    if data is None:
        data = {
            "X_train": [[[0.0] * 256 for _ in range(2)] for _ in range(100)],
            "y_train": [0] * 100,
            "num_classes": 11,
        }
    client = create_client(station_id, data)
    fl.client.start_numpy_client(server_address=server_address, client=client)
