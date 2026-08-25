- Doc:
    - How to build MPICH in Spack that can still communicate through the Cray's interconnect:

    ```yml
    libfabric:
      buildable: false
      externals:
      - spec: libfabric@2.3.1 fabrics=cxi
        prefix: /opt/cray/libfabric/2.3.1
    ```

    The key is to at minimum include libfabric as non-buildable dependencies. This is still inferior than also including both `cray-pmi` and `cray-mpich` as non-buildable.
