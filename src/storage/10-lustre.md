---
title: "Lustre file system"
output-file: lustre
---

On LUSTRE file system, use

``` sh
lfs quota -hp $(lfs project -d $d | awk '{print $1}') $d
```

to check the quota available in a certain directory.

For example, if you have separate storage quota for these directories, \$HOME \$SCRATCHDIR \$PROJECTDIR, then run

``` sh
for d in $HOME $SCRATCHDIR $PROJECTDIR; do
    echo ============================
    echo "Quota for $d:"
    lfs quota -hp $(lfs project -d $d | awk '{print $1}') $d;
done
```

to check the quota of them all at once.

::: callout-tip
Write this in a script called `myquota` in your PATH or a shell function to reuse it.
:::

TODO: add more tips from <https://github.com/ickc/isambard-workspace/tree/main/lustre>.
