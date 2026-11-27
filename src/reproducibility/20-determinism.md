---
title: "Seeds, and the order of a sum"
description: "The two principles behind a program that gives the same output every run, a fixed seed and a fixed order of execution; why the π of the part on parallelism prints the same line on every page; a sum of floats that changes with the number of pieces it is split into, and with the order the pieces finish; where the same happens in OpenMP, Numba, BLAS and MPI; and the fixes, cheapest first."
output-file: determinism
---

[The introduction](10-intro.md) ended with capturing every input. The first ones to capture are those inside your own program, and this page is about the two that matter most: the seed of its random numbers, and the order in which it adds things up.

## The recipe

Say your analysis draws random numbers and adds them up, in a loop that Numba runs on threads:

``` python
import numpy as np
from numba import njit, prange

@njit(parallel=True)
def total(x):
    s = 0.0
    for i in prange(x.size):
        s += x[i]
    return s

x = np.random.default_rng().standard_normal(1_000_000)
print(total(x))
```

Run it twice, and it prints two different numbers. Give the generator a seed, `default_rng(2026)`, and the numbers agree in all but their last few digits, which still change with the number of threads.[^1] There are two problems here, and their fixes are two principles.

**The weak principle**: a program whose randomness all comes from a generator with a fixed seed gives the same output for the same seed. The seed was hidden state, and fixing it makes it an input.

**The strong principle**: a program that also runs its operations in a fixed order gives byte-identical output. This is usually called bit-for-bit, or bitwise, reproducibility. The order matters because floating-point addition rounds every result to the nearest number it can represent, so adding the same numbers in a different order can round differently: in Python, `(0.1 + 0.2) + 0.3` is `0.6000000000000001`, and `0.1 + (0.2 + 0.3)` is `0.6`. The same source compiled for another CPU may also run different operations, so byte-identical holds on one architecture, and the architecture is one more input.[^2]

## Why π is the same on every page

Every page of [Parallelism](../parallel/10-intro.md) ends with the same line,

``` text
pi = 3.141543 from 4294967296 samples
```

whatever ran it: one core, a pool of processes, a job array, MPI ranks or Dragon. That is by design: each task's seed is an input, its number from 1 to 64, combined with one shared by all of them as a footnote there explains, so each task draws the same points however it is run. And the reduce adds integers, the hits, and integer addition is exact in any order. The only floating-point operation is the division at the end, done once. So π obeys the strong principle, on any number of workers, in any order. What it still depends on is NumPy, and the machine: [NumPy promises](https://numpy.org/doc/stable/reference/random/compatibility.html) the same numbers for the same seed only from the same build of NumPy, in the same environment, on the same machine, which is what the next pages are about.

## A sum that is not the same

Floats added in a different order can round differently, and this example shows what that does. It draws a million random floats between -1 and 1, once, from one seed, so that the list is the same however it is split, then splits it into pieces and adds them up on [a pool of processes](../parallel/tasks/30-python-pool.md):

``` {.python include="../examples/float-sum/float_sum.py"}
```

`split` cuts the list into as many pieces as asked, and `piece_sum` adds up one piece, one float at a time, as a loop, or a threaded reduction, does.[^3] The sums of the pieces are then added up three ways: in the order the pieces were submitted, which is the order `pool.map` returns them in, whichever worker finished first; in the order the workers finish them, with `as_completed`; and exactly, as below. The job runs it with 1, 8 and 64 pieces, twice:

``` {.bash include="../examples/float-sum/job.sh"}
```

Its output is[^4]

``` text
1000000 floats on 8 workers, math.fsum of the whole list: -792.0369761826319
pieces  in order            as they finish      exactly
     1  -792.0369761826661  -792.0369761826661  -792.0369761826319
     8  -792.0369761826179  -792.036976182618   -792.0369761826319
    64  -792.0369761826325  -792.0369761826327  -792.0369761826319
1000000 floats on 8 workers, math.fsum of the whole list: -792.0369761826319
pieces  in order            as they finish      exactly
     1  -792.0369761826661  -792.0369761826661  -792.0369761826319
     8  -792.0369761826179  -792.0369761826181  -792.0369761826319
    64  -792.0369761826325  -792.0369761826324  -792.0369761826319
```

The column in order is different for every number of pieces, in its last three digits, and the same in both runs. Splitting the list differently changes the order of the additions, so the number of pieces is an input. A threaded reduction splits its loop into one piece per thread, so for it, the input is the number of threads.

The column as they finish is different again, and changes from one run to the next. With the number of pieces fixed, adding their sums in the order they finish makes the order of the additions depend on timing, which no seed can fix, so even a fixed number of workers does not repeat.[^5] This is easy to do by accident, since `as_completed` is the natural way to collect results as soon as they are ready.

The column exactly is the same in every row, and the same as `math.fsum` of the whole list. [`math.fsum`](https://docs.python.org/3/library/math.html#math.fsum) keeps exact partial sums as it goes, so its result does not depend on the order of the list. But it takes the whole list in one call: an `fsum` of each piece is already rounded, and an `fsum` of those can differ in its last digit. So `exact_sum` returns the sum of a piece as a `Fraction`, which holds any float exactly, and adding `Fraction`s never rounds, so the one rounding is `float()`, at the end.

## Where this happens without you writing the sum

You rarely write the loop yourself, but the same splitting and combining happens inside the libraries you call:

- **OpenMP**, in a loop with `reduction(+:s)`, combines the threads' partial results in an order its [specification](https://www.openmp.org/spec-html/5.0/openmpsu107.html) leaves unspecified, and it says there is no guarantee of bitwise-identical results between two parallel runs, even with the same number of threads.
- **Numba**, in a `prange` loop that adds into one variable, as at the top of this page, does the same.
- **BLAS** splits its work between threads. With NumPy on OpenBLAS, the dot product of two long vectors changes in its last digits with the number of threads.
- **MPI**, in `MPI_Reduce` and `MPI_Allreduce`, [may combine the ranks' values in any order](https://www.mpi-forum.org/docs/mpi-4.1/mpi41-report/node130.htm). The standard strongly recommends that an implementation give the same result for the same arguments in the same order, which a different number of ranks is not, and tells a program that needs one particular order to gather the values and reduce them itself, with `MPI_Reduce_local`.

So the number of threads, and of ranks, is an input, as much as the seed. [The page on threads](../parallel/20-threads.md#the-environment-variables) is how to set it, for every library at once.

## The fixes, cheapest first

**Integers, or an exact sum, where the problem allows.** π counts hits rather than adding up fractions of them, so its reduce is exact in any order, on any number of workers, at no cost. Where what you add up is a count, keep it an integer until the end. Where it is floats, `math.fsum` in one process, or exact partial sums as in `exact_sum`, cost time, about a second for a million `Fraction`s on one core, but make the order irrelevant.

**A fixed order of combining.** Split the work into a fixed number of pieces, whatever the number of workers, and combine their results in the order of the pieces, with `pool.map` rather than `as_completed`. The column in order depends on the pieces only: 64 pieces give the same sum on 1 worker or on 8, which is what π does with its 64 tasks. Inside a library, the equivalent is to fix the number of threads, and for MPI, the number of ranks. Some libraries have a mode that fixes their order for you, at some cost in speed, which [the page on the machine](40-machine.md#intel-mkls-conditional-numerical-reproducibility) comes back to for Intel MKL.

**Otherwise, a declared tolerance.** When neither is practical, say how close two results have to be to count as the same, which is the equivalence from [the introduction](10-intro.md), and check every rerun against one reference result, e.g. with `math.isclose(result, reference, rel_tol=1e-12)` in Python.

The largest input outside your program is the software it runs with, and [the next page](30-environment.md) is about freezing that.

[^1]: And, with the threading layer Numba [picks first](https://numba.readthedocs.io/en/stable/user/threading-layer.html) when TBB is installed, from one run to the next with the same number of threads.

[^2]: GCC, for example, by default [fuses a multiply and an add](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-ffp-contract) into one instruction, which rounds once where the two would round twice, wherever the CPU has such an instruction. Every `aarch64` CPU has one, while on `x86_64` GCC uses it only when told the CPU has it, e.g. with `-march=native`.

[^3]: The loop, rather than Python's `sum`, which since Python 3.12 [adds floats more accurately](https://docs.python.org/3/library/functions.html#sum): with `sum`, the differences are rarer, but they don't go away.

[^4]: Measured on 8 cores of an x86 workstation. Apart from the column as they finish, the numbers are the same on any machine: Python's floats follow the same standard everywhere, and [`random.random` promises](https://docs.python.org/3/library/random.html#notes-on-reproducibility) the same sequence for the same seed in every version of Python, which it does not promise for the rest of `random`.

[^5]: On an idle computer, pieces of the same size tend to finish in the order they were submitted, so `piece_sum` first sleeps for up to 0.1 s, at random, standing in for real tasks, which take more or less time from one run to the next, the more so on a node shared with other jobs.
