#!/usr/bin/env python3
"""Monte Carlo π on a pool of processes, one for each CPU this job may use."""

import os
from concurrent.futures import ProcessPoolExecutor

import pi

if __name__ == "__main__":
    workers = len(os.sched_getaffinity(0))
    with ProcessPoolExecutor(max_workers=workers) as pool:
        hits = sum(pool.map(pi.count_hits, range(1, pi.TASKS + 1)))
    pi.report(hits, pi.TASKS * pi.SAMPLES)
