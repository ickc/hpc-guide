#!/usr/bin/env python3
"""Monte Carlo π on a multiprocessing pool that spans every node of the job, with Dragon:

    dragon pi_dragon.py
"""

import dragon  # noqa: F401  # before multiprocessing, which it patches

import multiprocessing as mp
import socket
from collections import Counter

import pi


def count_hits(seed):
    """One task, and the node it ran on."""
    return pi.count_hits(seed), socket.gethostname()


if __name__ == "__main__":
    mp.set_start_method("dragon")
    # With Dragon, cpu_count() is the number of CPUs of all the nodes together.
    workers = mp.cpu_count()
    print(f"{workers} workers")
    with mp.Pool(workers) as pool:
        results = pool.map(count_hits, range(1, pi.TASKS + 1))
    for host, tasks in sorted(Counter(host for _, host in results).items()):
        print(f"{host}: {tasks} tasks")
    pi.report(sum(hits for hits, _ in results), pi.TASKS * pi.SAMPLES)
