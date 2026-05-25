"""Classical-quantum hybrid optimizer with fallback strategies."""

from dataclasses import dataclass, field
from typing import Optional, Callable
from enum import Enum

import numpy as np


class FallbackStrategy(Enum):
    CLASSICAL_ONLY = "classical_only"
    SIMULATED_ANNEALING = "simulated_annealing"
    GREEDY = "greedy"
    RANDOM = "random"


@dataclass
class HybridResult:
    success: bool
    solution: np.ndarray
    value: float
    method_used: str
    quantum_calls: int
    classical_iterations: int
    fallback_triggered: bool
    history: list[float]
    timing: dict[str, float]


class HybridOptimizer:
    def __init__(
        self,
        num_vars: int,
        quantum_optimizer=None,
        fallback_strategy: FallbackStrategy = FallbackStrategy.SIMULATED_ANNEALING,
        quantum_threshold: float = 0.1,
        max_quantum_calls: int = 10,
        seed: Optional[int] = None,
    ):
        self.num_vars = num_vars
        self.quantum_optimizer = quantum_optimizer
        self.fallback_strategy = fallback_strategy
        self.quantum_threshold = quantum_threshold
        self.max_quantum_calls = max_quantum_calls
        self.rng = np.random.default_rng(seed)

    def optimize(
        self,
        objective_fn: Callable[[np.ndarray], float],
        quantum_backend=None,
        shots: int = 1024,
        max_iter: int = 1000,
    ) -> HybridResult:
        import time
        start_time = time.time()
        history = []
        fallback_triggered = False
        quantum_calls = 0
        classical_iterations = 0
        method_used = "quantum"

        best_solution = None
        best_value = float("inf")

        if self.quantum_optimizer is not None and quantum_backend is not None:
            try:
                q_result = self.quantum_optimizer.optimize(
                    backend=quantum_backend,
                    shots=shots,
                    max_iter=max_iter // 2,
                )
                quantum_calls = q_result.num_iterations
                history.extend(q_result.history)
                if hasattr(q_result, 'optimal_params'):
                    best_solution = q_result.optimal_params
                    best_value = q_result.optimal_value
                elif hasattr(q_result, 'optimal_betas'):
                    best_solution = np.concatenate([q_result.optimal_betas, q_result.optimal_gammas])
                    best_value = q_result.optimal_value
            except Exception:
                fallback_triggered = True

        if best_solution is None or (fallback_triggered and best_value > self.quantum_threshold):
            method_used = self.fallback_strategy.value
            fallback_triggered = True
            quantum_calls = 0

            if self.fallback_strategy == FallbackStrategy.SIMULATED_ANNEALING:
                best_solution, best_value, classical_iterations = self._simulated_annealing(
                    objective_fn, max_iter=max_iter
                )
                history.extend([best_value] * (classical_iterations // 10 + 1))
            elif self.fallback_strategy == FallbackStrategy.GREEDY:
                best_solution, best_value, classical_iterations = self._greedy_search(
                    objective_fn, max_iter=max_iter
                )
            elif self.fallback_strategy == FallbackStrategy.RANDOM:
                best_solution, best_value, classical_iterations = self._random_search(
                    objective_fn, max_iter=max_iter
                )
            elif self.fallback_strategy == FallbackStrategy.CLASSICAL_ONLY:
                best_solution, best_value, classical_iterations = self._classical_optimization(
                    objective_fn, max_iter=max_iter
                )

        elapsed = time.time() - start_time

        return HybridResult(
            success=best_solution is not None,
            solution=best_solution if best_solution is not None else np.zeros(self.num_vars),
            value=best_value if best_value != float("inf") else 0.0,
            method_used=method_used,
            quantum_calls=quantum_calls,
            classical_iterations=classical_iterations,
            fallback_triggered=fallback_triggered,
            history=history,
            timing={"total_seconds": elapsed},
        )

    def _simulated_annealing(
        self, objective_fn: Callable[[np.ndarray], float], max_iter: int = 1000
    ) -> tuple[np.ndarray, float, int]:
        current = self.rng.uniform(-np.pi, np.pi, self.num_vars)
        current_val = objective_fn(current)
        best = current.copy()
        best_val = current_val
        temp_start = 10.0
        temp_end = 0.01

        for iteration in range(max_iter):
            t = temp_start * (temp_end / temp_start) ** (iteration / max_iter)
            perturbation = self.rng.normal(0, t / temp_start, self.num_vars)
            candidate = current + perturbation
            candidate_val = objective_fn(candidate)
            delta = candidate_val - current_val
            if delta < 0 or self.rng.random() < np.exp(-delta / (t + 1e-10)):
                current = candidate
                current_val = candidate_val
                if current_val < best_val:
                    best = current.copy()
                    best_val = current_val

        return best, best_val, max_iter

    def _greedy_search(
        self, objective_fn: Callable[[np.ndarray], float], max_iter: int = 1000
    ) -> tuple[np.ndarray, float, int]:
        best = self.rng.uniform(-np.pi, np.pi, self.num_vars)
        best_val = objective_fn(best)
        iterations = 0

        for _ in range(max_iter):
            improved = False
            for i in range(self.num_vars):
                for delta in [0.1, -0.1]:
                    candidate = best.copy()
                    candidate[i] += delta
                    candidate_val = objective_fn(candidate)
                    iterations += 1
                    if candidate_val < best_val:
                        best = candidate
                        best_val = candidate_val
                        improved = True
                        break
                if improved:
                    break
            if not improved:
                break

        return best, best_val, iterations

    def _random_search(
        self, objective_fn: Callable[[np.ndarray], float], max_iter: int = 1000
    ) -> tuple[np.ndarray, float, int]:
        best = self.rng.uniform(-np.pi, np.pi, self.num_vars)
        best_val = objective_fn(best)

        for _ in range(max_iter):
            candidate = self.rng.uniform(-np.pi, np.pi, self.num_vars)
            candidate_val = objective_fn(candidate)
            if candidate_val < best_val:
                best = candidate
                best_val = candidate_val

        return best, best_val, max_iter

    def _classical_optimization(
        self, objective_fn: Callable[[np.ndarray], float], max_iter: int = 1000
    ) -> tuple[np.ndarray, float, int]:
        from scipy.optimize import minimize
        x0 = self.rng.uniform(-np.pi, np.pi, self.num_vars)
        result = minimize(objective_fn, x0, method="L-BFGS-B", options={"maxiter": max_iter})
        return result.x, result.fun, result.nfev

    def __repr__(self) -> str:
        return f"HybridOptimizer(vars={self.num_vars}, fallback={self.fallback_strategy.value})"
