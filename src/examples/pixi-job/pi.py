"""Estimate pi from the fraction of random points in the unit square inside the quarter circle."""

import sys

import numpy as np

n = 10_000_000
rng = np.random.default_rng(42)
x, y = rng.random(n), rng.random(n)
inside = np.count_nonzero(x * x + y * y <= 1.0)
print(f"pi is about {4 * inside / n:.4f}, from numpy {np.__version__} in {sys.prefix}")
