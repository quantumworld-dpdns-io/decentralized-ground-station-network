"""Signal classification model for federated training (PyTorch CNN)."""
import logging
from typing import Any

import torch
import torch.nn as nn
import torch.nn.functional as F

logger = logging.getLogger(__name__)


class SignalCNN(nn.Module):
    """CNN for RF signal modulation classification."""

    def __init__(self, num_classes: int = 11, input_channels: int = 2, dropout: float = 0.5):
        super().__init__()
        self.conv1 = nn.Conv1d(input_channels, 64, kernel_size=7, padding=3)
        self.bn1 = nn.BatchNorm1d(64)
        self.conv2 = nn.Conv1d(64, 128, kernel_size=5, padding=2)
        self.bn2 = nn.BatchNorm1d(128)
        self.conv3 = nn.Conv1d(128, 256, kernel_size=3, padding=1)
        self.bn3 = nn.BatchNorm1d(256)
        self.pool = nn.MaxPool1d(2)
        self.dropout = nn.Dropout(dropout)
        self.fc1 = nn.Linear(256 * 32, 256)
        self.fc2 = nn.Linear(256, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.pool(F.relu(self.bn1(self.conv1(x))))
        x = self.pool(F.relu(self.bn2(self.conv2(x))))
        x = self.pool(F.relu(self.bn3(self.conv3(x))))
        x = x.view(x.size(0), -1)
        x = self.dropout(F.relu(self.fc1(x)))
        x = self.fc2(x)
        return x


def get_model(num_classes: int = 11) -> SignalCNN:
    """Create a fresh SignalCNN model."""
    return SignalCNN(num_classes=num_classes)


def get_parameters(model: nn.Module) -> list[torch.Tensor]:
    """Get model parameters as a list of tensors."""
    return [p.data for p in model.parameters()]


def set_parameters(model: nn.Module, parameters: list[torch.Tensor]):
    """Set model parameters from a list of tensors."""
    for param, new_param in zip(model.parameters(), parameters):
        param.data.copy_(new_param)


def count_parameters(model: nn.Module) -> int:
    """Count total trainable parameters in the model."""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)
