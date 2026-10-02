#!/bin/sh
# A mighty POSIX shell script to be used to preseed computational
# tools (original domain - neuroimaging) with a specified and/or
# displayed seed for RNG, so that results have higher chance to be
# identical if recomputed if the same seed is provided
#
# TODOs: see/file an issue at https://github.com/ReproNim/reproseed/issues

if [ -z "$REPROSEED" ]; then
    REPROSEED=$(bash -c 'echo $RANDOM')
    _reproseed_src="random"
else
    _reproseed_src="provided"
fi

_setfor=""

while read -r _toolkit _var_more; do
    _var=${_var_more%% *}
    _more=${_var_more#* }
    eval "export $_var='$REPROSEED' $_more"
    _setfor="$_setfor $_toolkit"
done << EOF
AFNI AFNI_RANDOM_SEEDVAL
ANTs ANTS_RANDOM_SEED
PyMVPA MVPA_SEED
FreeSurfer FREESURFER_SEED
GSL GSL_RNG_SEED GSL_RNG_TYPE="taus"
EOF

export REPROSEED
echo "I: REPROSEED=$REPROSEED ($_reproseed_src) set for $_setfor" >&2

# Restrict CPU-specific (SIMD) code paths, see docs/cpu-features.md
_cpu_arch=$(uname -m)
case "$_cpu_arch" in
    x86_64) REPROSEED_CPU=${REPROSEED_CPU:-x86-64-v3};;
    *) REPROSEED_CPU=${REPROSEED_CPU:-native};;
esac

_cpu_level=""
_cpu_confirmed=""
case "$REPROSEED_CPU:$_cpu_arch" in
    native:*) ;;
    x86-64-v3:x86_64)
        _cpu_level="$REPROSEED_CPU"
        if grep -qsw avx2 /proc/cpuinfo && grep -qsw fma /proc/cpuinfo; then
            _cpu_confirmed=1
        fi;;
    *) echo "W: REPROSEED_CPU=$REPROSEED_CPU is not supported on $_cpu_arch" \
            "(supported: x86-64-v3 on x86_64, native)" >&2;;
esac

_cpu_notset=""

# "force" variables select code for the level, which crashes if unsupported
while read -r _how _var _value; do
    [ -n "$_cpu_level" ] || continue
    if [ "$_how" = "force" ] && [ -z "$_cpu_confirmed" ]; then
        _cpu_notset="$_cpu_notset $_var"
        continue
    fi
    if [ "$_var" = "NPY_DISABLE_CPU_FEATURES" ]; then
        # avoid NumPy warnings if there is no AVX512 to disable
        if [ -r /proc/cpuinfo ] && ! grep -qw avx512f /proc/cpuinfo; then
            continue
        fi
        # NumPy refuses to import if both are set
        if [ -n "${NPY_ENABLE_CPU_FEATURES:-}" ]; then
            echo "W: NPY_ENABLE_CPU_FEATURES is set, not setting $_var" >&2
            continue
        fi
    fi
    eval "_cur=\${$_var:-}"
    if [ -n "$_cur" ] && [ "$_cur" != "$_value" ]; then
        echo "W: overriding $_var=$_cur" >&2
    fi
    export "$_var=$_value"
done << EOF
limit NPY_DISABLE_CPU_FEATURES AVX512F AVX512_SKX AVX512_ICL AVX512_SPR X86_V4
force OPENBLAS_CORETYPE Haswell
limit MKL_CBWR AVX2
force ATEN_CPU_CAPABILITY avx2
limit ONEDNN_MAX_CPU_ISA AVX2
limit DNNL_MAX_CPU_ISA AVX2
EOF

if [ -n "$_cpu_notset" ]; then
    echo "W: could not confirm that CPU supports $REPROSEED_CPU (AVX2, FMA)," \
         "not setting$_cpu_notset; results might differ from $REPROSEED_CPU CPUs" >&2
fi

export REPROSEED_CPU

if [ "$#" -gt 0 ]; then
    echo I: reproseed.sh - running "$@" >&2
    "$@"
fi
