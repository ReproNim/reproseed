# reproseed

A POSIX shell script to assist in guaranteeing reproducible
non-deterministic computation(s).

## Rationale

Many computational tools initialize some parts of computation based on
random numbers.  Typically the Pseudo Random Number Generators (RNG)
used for that purpose could be pre-seeded, thus often (but not always,
if e.g. computation is also parallelized and results depend on the
order of the elements in the reduction step) making results
reproducible.  Typically such tools allow to specify the `seed`
integer for their RNGs via some environment variable, but there is no
agreement on the name of such a variable.

That is where `reproseed` comes to help.  You can either specify your
desired random seed in environment variable `REPROSEED` or it will
generate a new random one.  In either of those cases, it will then
display that seed on stderr (so you could use it later to reproduce the
results), and export corresponding environment variables with its
value for other tools it is aware about (e.g., [PyMVPA][pymvpa],
[AFNI][afni], [ANTs][ants]).

Even with the same seed, results could differ when the same computation
is run on different machines, because numerical libraries choose
CPU-specific (SIMD) code paths at run time.  Therefore `reproseed` also
restricts them to a common CPU features level.

## CPU features

`REPROSEED_CPU` specifies the [x86-64 microarchitecture level][x86-64-levels]
to restrict computation to, and defaults to `x86-64-v3` (AVX2 and FMA)
on x86-64.  It is achieved by setting

| Library                | Variable                                  |
|------------------------|-------------------------------------------|
| [NumPy][numpy]         | [`NPY_DISABLE_CPU_FEATURES`][npy-disable] |
| [OpenBLAS][openblas]   | [`OPENBLAS_CORETYPE`][openblas-vars]      |
| [MKL][mkl]             | [`MKL_CBWR`][mkl-cbwr]                    |
| [PyTorch][pytorch]     | [`ATEN_CPU_CAPABILITY`][aten-cpu]         |
| [oneDNN][onednn]       | [`ONEDNN_MAX_CPU_ISA`][onednn-isa]        |
| [oneDNN][onednn] < 2.5 | [`DNNL_MAX_CPU_ISA`][dnnl-isa]            |

Set `REPROSEED_CPU=native` to not restrict, e.g. for speed when results
need not be compared across machines.  See
[docs/cpu-features.md](docs/cpu-features.md) for details and caveats.

## HOWTO

Just download `reproseed.sh` to your computer or install within your
container, and either

- `source reproseed.sh` (or `. reproseed.sh`) in your script before
  running your computation
- execute your computation script via `reproseed`, e.g.

      ./reproseed.sh myscript -param1 arg1

[afni]: https://afni.nimh.nih.gov
[ants]: https://github.com/ANTsX/ANTs
[aten-cpu]: https://github.com/pytorch/pytorch/blob/v2.14.1/aten/src/ATen/native/DispatchStub.cpp#L30
[dnnl-isa]: https://github.com/uxlfoundation/oneDNN/blob/v2.4/src/cpu/x64/cpu_isa_traits.cpp#L34
[mkl]: https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl.html
[mkl-cbwr]: https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2025-2/specifying-code-branches.html
[npy-disable]: https://numpy.org/doc/stable/reference/simd/build-options.html#runtime-dispatch
[numpy]: https://numpy.org
[onednn]: https://github.com/uxlfoundation/oneDNN
[onednn-isa]: https://uxlfoundation.github.io/oneDNN/dev_guide_cpu_dispatcher_control.html
[openblas]: https://www.openmathlib.org/OpenBLAS/
[openblas-vars]: https://www.openmathlib.org/OpenBLAS/docs/runtime_variables/
[pymvpa]: https://www.pymvpa.org
[pytorch]: https://pytorch.org
[x86-64-levels]: https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels
