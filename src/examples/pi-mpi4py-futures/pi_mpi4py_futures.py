#!/usr/bin/env python3
"""Monte Carlo π on MPI ranks, with mpi4py.futures:

    srun python -m mpi4py.futures pi_mpi4py_futures.py

Rank 0 runs this script and hands out the tasks; every other rank is a worker.
"""

import socket
from collections import Counter

from mpi4py import MPI
from mpi4py.futures import MPIPoolExecutor

import pi


def count_hits(seed):
    """One task, and the node it ran on."""
    return pi.count_hits(seed), socket.gethostname()


if __name__ == "__main__":
    print(f"{MPI.COMM_WORLD.Get_size() - 1} workers")
    with MPIPoolExecutor() as pool:
        results = list(pool.map(count_hits, range(1, pi.TASKS + 1)))
    for host, tasks in sorted(Counter(host for _, host in results).items()):
        print(f"{host}: {tasks} tasks")
    pi.report(sum(hits for hits, _ in results), pi.TASKS * pi.SAMPLES)
