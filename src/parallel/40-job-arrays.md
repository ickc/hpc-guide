---
title: "Job arrays"
description: "Many independent tasks beyond one node, as a Slurm job array: --array, throttling with %, the task ID and the output names, a reduce job that waits with --dependency=afterok, the load arrays put on the scheduler, and an array whose every task runs GNU parallel on a whole node."
output-file: job-arrays
---

[On one node](30-one-node.md), one job runs all the tasks. When there are more than one node can get through in the time of one job, the simplest way out is to let the scheduler run them for you, each task as a job of its own, on whichever nodes are free.

## One submission for many jobs

You may be tempted to submit them in a loop, on the login node:

``` bash
for seed in $(seq 1 64); do
    sbatch job.sh "$seed"
done
```

That works, and gives you 64 jobs, each with its own job ID, to keep track of and cancel one by one. A *job array* is the same in one submission: one job script, submitted once, which Slurm runs as many *array tasks*, each with its own index.

``` {.bash include="../examples/pi-array/job.sh"}
```

`--array=1-64%16` makes 64 array tasks, with indices 1 to 64, and runs at most 16 of them at a time. The `%16` is the *throttle*: without it, Slurm runs as many as there are free resources for, which is fine for 64, but with thousands, a throttle stops your array from taking over the cluster, or your share of it, and leaves room for your other jobs.[^1]

Each array task runs the whole script, with the resources the script asks for, here 1 CPU, and with its own index in `SLURM_ARRAY_TASK_ID`. That is all that tells the tasks apart, so it is the index that picks the task's work: here it is the seed, and in your case it might pick the line of a task list, with `sed -n "${SLURM_ARRAY_TASK_ID}p" tasks.txt`.

Each task writes its result to `results/<index>.txt`. Its output goes to `pi-array-%A_%a.out`, where `%A` is the job ID of the array, and `%a` the index of the task, so each task gets its own file. Without `%a` in the name, the tasks would write to the same file, and overwrite each other's output.

In `squeue --me`, the running tasks show up one per line, as `<job ID>_<index>`, and those still waiting all together on one line. `scancel <job ID>` cancels the whole array, and `scancel <job ID>_<index>` one task.

## The reduce, after every task

The results still need adding up, and that has to wait until all 64 tasks are done. A job can wait for another with `--dependency`, so the reduce is a job of its own:

``` {.bash include="../examples/pi-array/reduce.sh"}
```

submitted together with the array by a script you run on the login node:

``` {.bash include="../examples/pi-array/submit.sh"}
```

`sbatch --parsable` prints only the job ID, so the script can pass it on, and `--dependency=afterok:<job ID>` keeps the reduce job in the queue until that job has finished successfully. Given the job ID of an array, it waits for every one of its tasks.[^2] Its output ends with the same line as every other strategy:

``` text
pi = 3.141543 from 4294967296 samples
```

If a task fails, the dependency can never be satisfied, and the reduce job stays in the queue, waiting for something that won't happen, until you cancel it (unless your cluster is set to cancel such jobs by itself). To find which tasks failed, `sacct -j <job ID> -X --format=JobID,State,ExitCode` lists every task with its state; once you've fixed the problem, rerun only those, e.g. `sbatch --array=5,17 job.sh`, since an option on the command line overrides the one in the script, then submit the reduce again.

That is as far as dependencies go on this page. A pipeline with more steps than one reduce is the subject of the page on workflows (`80-workflows`), later in this part.

## The limit: overwhelming the scheduler

The convenience comes with a cost. Each array task is a job, with everything that comes with one: the scheduler has to find room for it, start it, track it while it runs, and account for it after it ends. An array is cheaper for the scheduler than as many separate jobs, but 10,000 array tasks are still 10,000 jobs to schedule, and the scheduler is shared by everyone on the cluster. When the scheduler is overwhelmed, it is slow for all of them, `squeue` and `sbatch` included.

Each task also pays for itself. It waits in the queue, then starts from nothing: a new shell, activating the environment, starting Python and importing NumPy, all reading from the shared filesystem, the [cost of activation](../package-managers/30-conda.md) multiplied by the number of tasks. For a task that takes an hour, none of that matters. For one that takes 10 seconds, it can be more than the task itself.

Clusters protect themselves with limits. `MaxArraySize` in Slurm's configuration caps the indices of an array (by default, 1001, so indices up to 1000), and many clusters also limit how many jobs one user can have in the queue, which a large array can run into. `scontrol show config | grep -i MaxArraySize` shows the first.

::: {.callout-note title="For example, on Isambard 3"}
Isambard's [Slurm troubleshooting guide](https://docs.isambard.ac.uk/user-documentation/guides/slurm-troubleshooting/) lists `QOSMaxSubmitJobPerUserLimit`, too many jobs queued, as a reason a job stays pending, and its [FAQ](https://docs.isambard.ac.uk/user-documentation/faqs/) warns that a large array with a long `--time` can reserve enough of a project's credits to block new submissions until some of its tasks complete.
:::

So an array is for tasks that are each worth a job: few enough, and long enough. When you have many short tasks, group them, so that each array task runs many of them.

## An array of whole nodes, each running GNU parallel

Nothing prevents you from mixing the two. An array where each task has a whole node to itself, and runs its share of the tasks with [GNU parallel](30-one-node.md#gnu-parallel) inside it, reduces the amount of spam to the scheduler to one job per node, while still going beyond one node:

``` {.bash include="../examples/pi-array-parallel/job.sh"}
```

`--exclusive` gives each array task a whole node, whatever its size, and `SLURM_CPUS_ON_NODE` is then the number of CPUs of that node, so GNU parallel runs one task per CPU.[^3] `SLURM_ARRAY_TASK_COUNT` is the number of array tasks, here 2, so the 64 seeds split into two shares of 32, the first array task taking 1 to 32 and the second 33 to 64. GNU parallel reads them from its input, made by `seq`.

The results go to the same `results/<seed>.txt` as before, so the reduce is the same job, submitted the same way:

``` {.bash include="../examples/pi-array-parallel/submit.sh"}
```

The sizes here are small, to keep the example quick: 2 nodes for 64 tasks of a second each is a waste of both. In real use, each array task's share would be hundreds or thousands of tasks, sized so that one node gets through them in a few hours, and the array would be as many nodes as you want to use at a time.

::: {.callout-note title="For example, on Isambard 3"}
A node of Isambard 3 has [144 cores](https://docs.isambard.ac.uk/user-documentation/information/how-isambard-works/), in two Grace CPUs of 72 each. So an array of 10 whole nodes runs 1,440 tasks at a time, as 10 jobs, where a plain array would need 1,440 array tasks running at once to do the same.
:::

This is where the tasks are no longer Python functions that one script hands out, but whole commands. When they are Python functions, and you want them spread over many nodes from one script, without an array, the next page, on `mpi4py.futures` (`50-mpi4py-futures`), does that, with MPI underneath.

[^1]: Indices need not start at 1, or be consecutive: `--array=0-90:10` is 0, 10, 20, ..., 90, and `--array=5,17` is just those two, which is useful for rerunning tasks that failed, below.

[^2]: `afterok` is the strictest kind of dependency. `afterany` waits for the tasks to finish whether or not they succeeded, and `aftercorr`, between two arrays, lets each task of the second start once the task with the same index in the first has succeeded. The [Slurm documentation on job arrays](https://slurm.schedmd.com/job_array.html) has the details.

[^3]: If the nodes of your cluster present two logical CPUs per core, and Slurm counts those, use `--jobs` half that, or GNU parallel's `--use-cores-instead-of-threads`, which makes its default of one task per CPU count physical cores instead. See the tip on [physical cores](20-threads.md#asking-for-the-cores).
