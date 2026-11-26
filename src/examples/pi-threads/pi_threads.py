#!/usr/bin/env python3
"""Monte Carlo π in one process, with a pool of threads: python pi_threads.py THREADS"""

import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import pi

threads = int(sys.argv[1])
start, cpu_start = time.perf_counter(), time.process_time()
with ThreadPoolExecutor(max_workers=threads) as pool:
    hits = sum(pool.map(pi.count_hits, range(1, pi.TASKS + 1)))
elapsed = time.perf_counter() - start
cpu = time.process_time() - cpu_start  # the CPU time of all the threads together

print(f"{threads} threads, on {len(os.sched_getaffinity(0))} CPUs: {elapsed:.1f} s, CPU use {100 * cpu / elapsed:.0f}%")
pi.report(hits, pi.TASKS * pi.SAMPLES)
