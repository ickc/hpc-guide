#!/usr/bin/env python3
"""Monte Carlo π, the example every page on parallelism solves.

Draw points uniformly in the unit square, and count the hits, the points that
land inside the quarter circle of radius 1. The fraction of hits is π/4.

    python pi.py count SEED...     print "hits samples" for each task
    python pi.py reduce [FILE...]  add up such lines, from files or stdin, and print π
"""

import fileinput
import sys

import numpy as np

TASKS = 64  # the whole problem is 64 tasks, with seeds 1 to 64
SAMPLES = 2**26  # points drawn by each task
ROOT_SEED = 2026  # the same for every task: the task's own seed tells them apart
CHUNK = 2**16  # points drawn at a time, to keep memory small


def count_hits(seed, samples=SAMPLES):
    """Count how many of `samples` random points land inside the quarter circle."""
    rng = np.random.default_rng([seed, ROOT_SEED])
    hits = 0
    for start in range(0, samples, CHUNK):
        xy = rng.random((min(CHUNK, samples - start), 2))
        hits += int(np.count_nonzero((xy * xy).sum(axis=1) <= 1.0))
    return hits


def report(hits, samples):
    print(f"pi = {4 * hits / samples:.6f} from {samples} samples")


def main():
    command, *args = sys.argv[1:]
    if command == "count":
        for seed in args:
            print(count_hits(int(seed)), SAMPLES)
    elif command == "reduce":
        hits = samples = 0
        for line in fileinput.input(args):
            h, s = map(int, line.split())
            hits += h
            samples += s
        report(hits, samples)
    else:
        sys.exit(f"unknown command {command!r}: use count or reduce")


if __name__ == "__main__":
    main()
