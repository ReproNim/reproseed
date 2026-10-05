# Restricting CPU features

Numerical libraries choose CPU-specific (SIMD) code paths at run time,
e.g. AVX512 `exp` in [NumPy][numpy] or matrix multiplication kernels in
[OpenBLAS][openblas], which can produce results differing in the last
bits on different CPUs. `reproseed.sh` configures supported libraries using
the [x86-64 microarchitecture profile][x86-64-levels] in `REPROSEED_CPU`.
This reduces one source of variation; it does not guarantee identical results
across hardware, library builds, or threading configurations.

On x86-64 it defaults to `x86-64-v3` (AVX2 and FMA, supported by most
CPUs since Intel Haswell and AMD Excavator/Zen), for which the
following variables are exported:

| Library                  | Variable                                  | Value       |
|--------------------------|-------------------------------------------|-------------|
| [NumPy][numpy]           | [`NPY_DISABLE_CPU_FEATURES`][npy-disable] | see below   |
| [OpenBLAS][openblas]     | [`OPENBLAS_CORETYPE`][openblas-vars]      | `Haswell`   |
| [MKL][mkl]               | [`MKL_CBWR`][mkl-cbwr]                    | `AVX2`      |
| [PyTorch][pytorch]       | [`ATEN_CPU_CAPABILITY`][aten-cpu]         | `avx2`      |
| [oneDNN][onednn]         | [`ONEDNN_MAX_CPU_ISA`][onednn-isa]        | `AVX2`      |
| [oneDNN][onednn] < 2.5   | [`DNNL_MAX_CPU_ISA`][dnnl-isa]            | `AVX2`      |

- `NPY_DISABLE_CPU_FEATURES` lists the AVX512 targets of NumPy < 2.4
  (`AVX512F AVX512_SKX AVX512_ICL AVX512_SPR`) and >= 2.4
  (`X86_V4 AVX512_ICL AVX512_SPR`), since disabling one target does not
  disable the others. Existing exclusions are retained and missing profile
  targets appended, so wrapping a command does not re-enable excluded paths.
  It is not set if `/proc/cpuinfo` shows no
  AVX512, or if [`NPY_ENABLE_CPU_FEATURES`][npy-enable] is set (NumPy
  refuses both).
- `OPENBLAS_CORETYPE` and `ATEN_CPU_CAPABILITY` select code for the
  level, which would crash on a CPU without AVX2 or FMA, so they are set
  only if `/proc/cpuinfo` confirms those.  That excludes some
  Pentium/Celeron/Atom CPUs, VMs with a generic CPU model (e.g.,
  `qemu64`), and non-Linux systems; results there might differ.
- `OPENBLAS_CORETYPE` affects only OpenBLAS builds with
  [`DYNAMIC_ARCH`][openblas-dynamic-arch], e.g. in NumPy wheels, Debian,
  conda-forge.
- oneDNN is used by PyTorch and [TensorFlow][tensorflow]. Its environment cap
  takes effect only when built with `ONEDNN_ENABLE_MAX_CPU_ISA=ON`; see the
  [dispatcher build and runtime controls][onednn-isa].
- An explicit `MKL_CBWR` is preserved, including `AVX2,STRICT` and
  `COMPATIBLE`. Settings outside the recognized AVX2-or-lower branches produce
  a warning because they may defeat a common CPU profile. Unknown values are
  preserved but are not validated by reproseed. Intel documents non-`AUTO`/
  `COMPATIBLE` branches as Intel-only, and unsupported branches may silently
  fall back to `AUTO`; exporting `AVX2` does not establish a common Intel/AMD
  branch. See [MKL branch semantics][mkl-cbwr].

Except for the NumPy exclusions and explicit MKL settings described above,
a different value already set for these variables is overridden with a warning.  With `REPROSEED_CPU=native` none of them is set (values
already in the environment are left as is).  It is the default on other
architectures (e.g., aarch64), for which no restrictions are implemented
(yet).

## Checking code paths in use

- NumPy and its OpenBLAS: [`numpy.show_runtime()`][numpy-show-runtime]
  (OpenBLAS `architecture` requires [threadpoolctl][threadpoolctl])
- PyTorch: [`torch.backends.cpu.get_cpu_capability()`][torch-cpu-capability]
- oneDNN: [`ONEDNN_VERBOSE=1`][onednn-verbose]

## Caveats

- NumPy warns on import about listed features it does not know (or, in
  NumPy 1.20-1.24, the CPU lacks): with an `ImportWarning`, hidden by
  default, since NumPy 1.25, but with a visible `RuntimeWarning` before.
  If warnings are turned into errors (e.g., `filterwarnings = error` in
  pytest), ignore those, or set `REPROSEED_CPU=native`.
- If `import numpy` fails with "You cannot disable CPU feature ...,
  since it is part of the baseline optimizations", that NumPy was built
  to require AVX512.  Set `REPROSEED_CPU=native`.
- Results of multi-threaded computation (e.g., OpenBLAS, MKL, OpenMP
  reductions, [ANTs][ants]) can also depend on the number of threads, so
  use the same [`OMP_NUM_THREADS`][omp-num-threads],
  [`OPENBLAS_NUM_THREADS`][openblas-vars],
  [`MKL_NUM_THREADS`][mkl-threads],
  [`ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS`][itk-threads] etc. when
  comparing results. For standard MKL CNR, also set `MKL_DYNAMIC=FALSE` and
  `OMP_DYNAMIC=FALSE`. Strict CNR relaxes the thread-count requirement only
  for selected operations, including GEMM; see [Intel reproducibility
  conditions][mkl-cnr].

[ants]: https://github.com/ANTsX/ANTs
[aten-cpu]: https://github.com/pytorch/pytorch/blob/v2.14.1/aten/src/ATen/native/DispatchStub.cpp#L30
[dnnl-isa]: https://github.com/uxlfoundation/oneDNN/blob/v2.4/src/cpu/x64/cpu_isa_traits.cpp#L34
[itk-threads]: https://github.com/InsightSoftwareConsortium/ITK/blob/v5.4.7/Modules/Core/Common/src/itkMultiThreaderBase.cxx#L296
[mkl]: https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl.html
[mkl-cbwr]: https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2025-2/specifying-code-branches.html
[mkl-threads]: https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2025-2/techniques-to-set-the-number-of-threads.html
[npy-disable]: https://numpy.org/doc/stable/reference/simd/build-options.html#runtime-dispatch
[npy-enable]: https://github.com/numpy/numpy/blob/v2.5.3/numpy/_core/src/common/npy_cpu_features.c#L53
[numpy]: https://numpy.org
[numpy-show-runtime]: https://numpy.org/doc/stable/reference/generated/numpy.show_runtime.html
[omp-num-threads]: https://www.openmp.org/spec-html/5.0/openmpse50.html
[onednn]: https://github.com/uxlfoundation/oneDNN
[onednn-isa]: https://uxlfoundation.github.io/oneDNN/dev_guide_cpu_dispatcher_control.html
[onednn-verbose]: https://uxlfoundation.github.io/oneDNN/dev_guide_verbose.html
[openblas]: https://www.openmathlib.org/OpenBLAS/
[openblas-dynamic-arch]: https://www.openmathlib.org/OpenBLAS/docs/faq/#how-to-choose-target-manually-at-runtime-when-compiled-with-dynamic_arch
[openblas-vars]: https://www.openmathlib.org/OpenBLAS/docs/runtime_variables/
[pytorch]: https://pytorch.org
[tensorflow]: https://www.tensorflow.org
[threadpoolctl]: https://github.com/joblib/threadpoolctl
[torch-cpu-capability]: https://docs.pytorch.org/docs/2.14/backends.html#torch.backends.cpu.get_cpu_capability
[x86-64-levels]: https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels

[mkl-cnr]: https://www.intel.com/content/www/us/en/docs/onemkl/developer-guide-linux/2025-2/reproducibility-conditions.html
