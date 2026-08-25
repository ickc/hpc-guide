TODO: introduce how to link libfabrics, etc. properly to compose an
environment with the vendor provided MPI

- How to build MPICH in Spack that can still communicate through the Cray's interconnect:

```yml
libfabric:
    buildable: false
    externals:
    - spec: libfabric@2.3.1 fabrics=cxi
    prefix: /opt/cray/libfabric/2.3.1
```

TODO: Cray's MPI
