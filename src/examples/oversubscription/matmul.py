#!/usr/bin/env python3
"""Multiply matrices with NumPy, whose BLAS may use threads, and report the CPU use."""

import time

import numpy as np

a = np.random.default_rng(0).random((1000, 1000))
start, cpu_start = time.perf_counter(), time.process_time()
for _ in range(50):
    a @ a
elapsed = time.perf_counter() - start
cpu = time.process_time() - cpu_start
print(f"{elapsed:.2f} s, CPU use {100 * cpu / elapsed:.0f}%")
