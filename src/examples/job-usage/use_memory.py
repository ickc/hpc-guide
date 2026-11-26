"""Hold about MIB mebibytes of memory, and keep one core busy for SECONDS.

    python3 use_memory.py MIB SECONDS
"""

import sys
import time

mib, seconds = int(sys.argv[1]), float(sys.argv[2])
# Filled with ones rather than left as zeros, so that every page of it is really used.
block = b"\x01" * (mib * 2**20)
start = time.perf_counter()
while time.perf_counter() - start < seconds:
    pass
print(f"held {len(block) // 2**20} MiB, busy for {seconds:g} s")
