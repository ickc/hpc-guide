#!/usr/bin/env python3
"""Monte Carlo π on MPI ranks, each with a pool of threads:

    srun python pi_hybrid.py THREADS

Each rank runs its share of the tasks on its threads, and rank 0 adds up the hits.
Rank 0 also prints where every rank ran: its node, its CPUs, and their NUMA nodes.
"""

import glob
import os
import socket
import sys
from concurrent.futures import ThreadPoolExecutor

from mpi4py import MPI

import pi


def parse(cpulist):
    """'0-3,8' -> {0, 1, 2, 3, 8}, as in /sys/devices/system/node/node*/cpulist."""
    cpus = set()
    for part in cpulist.strip().split(","):
        if part:
            first, _, last = part.partition("-")
            cpus.update(range(int(first), int(last or first) + 1))
    return cpus


def ranges(cpus):
    """{0, 1, 2, 3, 8} -> '0-3,8'"""
    parts, cpus = [], sorted(cpus)
    while cpus:
        first = last = cpus.pop(0)
        while cpus and cpus[0] == last + 1:
            last = cpus.pop(0)
        parts.append(f"{first}-{last}" if last > first else f"{first}")
    return ",".join(parts)


def numa_nodes(cpus):
    """The NUMA nodes that these CPUs belong to."""
    nodes = []
    for path in sorted(glob.glob("/sys/devices/system/node/node[0-9]*/cpulist")):
        with open(path) as f:
            if cpus & parse(f.read()):
                nodes.append(path.split("/")[-2].removeprefix("node"))
    return ",".join(nodes) or "?"


comm = MPI.COMM_WORLD
rank, size = comm.Get_rank(), comm.Get_size()
threads = int(sys.argv[1])

# This rank's share of the tasks: seeds rank + 1, rank + 1 + size, ...
with ThreadPoolExecutor(max_workers=threads) as pool:
    hits = sum(pool.map(pi.count_hits, range(rank + 1, pi.TASKS + 1, size)))

cpus = os.sched_getaffinity(0)
where = f"{socket.gethostname()}: {threads} threads on CPUs {ranges(cpus)}, NUMA node {numa_nodes(cpus)}"
places = comm.gather(where, root=0)
total = comm.reduce(hits, op=MPI.SUM, root=0)

if rank == 0:
    for r, where in enumerate(places):
        print(f"rank {r} on {where}")
    pi.report(total, pi.TASKS * pi.SAMPLES)
