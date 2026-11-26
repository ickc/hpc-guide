#!/usr/bin/env python3
"""Monte Carlo π with map_parallel on MPI ranks:

    srun python -m mpi4py.futures pi_map_parallel_mpi.py
"""

from map_parallel import map_parallel

import pi

if __name__ == "__main__":
    # The same as the version on one node, with mode="mpi" and no number of workers:
    # with python -m mpi4py.futures, that is every rank but rank 0.
    hits = sum(map_parallel(pi.count_hits, range(1, pi.TASKS + 1), mode="mpi"))
    pi.report(hits, pi.TASKS * pi.SAMPLES)
