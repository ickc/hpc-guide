#!/usr/bin/env python3
"""Check that mpi4py forms a single MPI world spanning every rank and node."""

from collections import Counter
import socket
import sys

from mpi4py import MPI

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()
host = socket.gethostname()

# Collective over every rank; the sum matches the world size only when
# all ranks (including those on other nodes) take part.
total = comm.allreduce(1, op=MPI.SUM)

# Gather each rank's host on rank 0 to show the rank-to-node mapping.
hosts = comm.gather(host, root=0)

if rank != 0:
    sys.exit(0)

ranks_per_host = Counter(hosts)
print(f"MPI library: {MPI.Get_library_version().splitlines()[0]}")
print(f"world size: {size}")
print(f"allreduce sum: {total} (expected {size})")
print(f"nodes in world: {len(ranks_per_host)}")
for name, count in sorted(ranks_per_host.items()):
    print(f"  {name}: {count} ranks")

if size > 1 and total == size:
    print("RESULT: PASS - one MPI world spans every rank")
    sys.exit(0)

print("RESULT: FAIL - ranks did not join a single MPI world")
sys.exit(1)
