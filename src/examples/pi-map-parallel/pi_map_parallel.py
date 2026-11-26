#!/usr/bin/env python3
"""Monte Carlo π with map_parallel, which runs map on a pool of workers."""

import os

from map_parallel import map_parallel

import pi

if __name__ == "__main__":
    # The serial version: hits = sum(map(pi.count_hits, range(1, pi.TASKS + 1)))
    hits = sum(map_parallel(pi.count_hits, range(1, pi.TASKS + 1), processes=len(os.sched_getaffinity(0))))
    pi.report(hits, pi.TASKS * pi.SAMPLES)
