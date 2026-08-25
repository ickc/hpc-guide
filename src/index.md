- Doc:
    - [ ] investigate and fix/doc why `conda activate ...` from login nodes doesn't propagate @inprogress
        -   recommend loading environment from login node first before submitting jobs (to minimize overhead for massively parallel applications), introduce heredoc. Depends on last bullet point
    - arch dependent prefix to avoid collision between i3 and macs 
    - find out more about the storage system and document it. E.g. https://github.com/gw4-isambard/rse-sharing/issues/4#issuecomment-4592097055 mentions about HDDs.
    - consolidate around conda: currently it is scattered around in multiple pages
    - consolidate recommendated approach to bootstrap conda/mamba/micromamba/pixi and the way to load the environment in batch job

        ```sh
        # best portability (miniforge3/conda/anaconda)
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda activate ...
        # tool specific
        eval "$(conda shell.bash hook)"
        eval "$(mamba shell hook -s bash)"
        eval "$(micromamba shell hook -s bash)"
        eval "$(pixi shell-hook -s bash)"
        ```
    - How to build MPICH in Spack that can still communicate through the Cray's interconnect:

    ```yml
    libfabric:
      buildable: false
      externals:
      - spec: libfabric@2.3.1 fabrics=cxi
        prefix: /opt/cray/libfabric/2.3.1
    ```

    The key is to at minimum include libfabric as non-buildable dependencies. This is still inferior than also including both `cray-pmi` and `cray-mpich` as non-buildable.
