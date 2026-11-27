#!/usr/bin/env python3
"""The same million random floats, between -1 and 1, added up in pieces on a pool of processes.

    python3 float_sum.py PIECES...

For each number of pieces, the list is split into that many, a worker adds up
each piece, and the sums of the pieces are added up three ways: in the order the
pieces were submitted, in the order the workers finish them, and exactly.
"""

import math
import os
import random
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from fractions import Fraction

N = 1_000_000  # how many floats
SEED = 2026  # the list is drawn once, from this seed, however it is split


def piece_sum(xs):
    """Add up the floats of one piece, one at a time, as a loop or a reduction does."""
    # Real tasks take more or less time from one run to the next; this stands in for that,
    # with up to 0.1 s from the unseeded generator, which is different in every run.
    time.sleep(random.random() / 10)
    total = 0.0
    for x in xs:
        total += x
    return total


def exact_sum(xs):
    """The exact sum of one piece: a float converts to a Fraction exactly, and adding Fractions never rounds."""
    return sum(map(Fraction, xs))


def split(xs, n):
    """Split xs into n contiguous pieces of nearly equal size."""
    size, extra = divmod(len(xs), n)
    bounds = [0]
    for i in range(n):
        bounds.append(bounds[-1] + size + (i < extra))
    return [xs[a:b] for a, b in zip(bounds, bounds[1:])]


def main():
    rng = random.Random(SEED)
    values = [2 * rng.random() - 1 for _ in range(N)]
    workers = len(os.sched_getaffinity(0))
    print(f"{N} floats on {workers} workers, math.fsum of the whole list: {math.fsum(values)!r}")
    print(f"{'pieces':>6}  {'in order':<20}{'as they finish':<20}exactly")
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for n in map(int, sys.argv[1:]):
            pieces = split(values, n)
            # The sums of the pieces in the order they were submitted, whichever worker finished first.
            in_order = 0.0
            for s in pool.map(piece_sum, pieces):
                in_order += s
            # The same sums, in the order the workers finish them.
            as_they_finish = 0.0
            for future in as_completed([pool.submit(piece_sum, p) for p in pieces]):
                as_they_finish += future.result()
            # The exact sums, added exactly, and rounded to a float once, at the end.
            exactly = float(sum(pool.map(exact_sum, pieces)))
            print(f"{n:>6}  {in_order!r:<20}{as_they_finish!r:<20}{exactly!r}")


if __name__ == "__main__":
    main()
