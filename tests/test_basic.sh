#!/usr/bin/env bats
# reproseed.sh is sourced via $REPROSEED_CMD, which shellcheck does not
# follow (-x crashes shellcheck 0.11.0 on `$(. file)`), so it does not know
# the variables reproseed.sh sets either
# shellcheck disable=SC1090,SC2153

# export PATH=$(dirname $0/..):$PATH
REPROSEED_CMD="./reproseed.sh"

common_checks() {
	# Common checks to see if all seeds in the environment are equal
	# to the desired value
	[ "$REPROSEED" = "$1" ]
	[ "$AFNI_RANDOM_SEEDVAL" = "$REPROSEED" ]
	[ "$MVPA_SEED" = "$REPROSEED" ]

}

CPU_VARS_RE='^(NPY_DISABLE_CPU_FEATURES|OPENBLAS_CORETYPE|MKL_CBWR|ATEN_CPU_CAPABILITY|ONEDNN_MAX_CPU_ISA|DNNL_MAX_CPU_ISA)='

setup() {
	unset REPROSEED_CPU NPY_DISABLE_CPU_FEATURES NPY_ENABLE_CPU_FEATURES \
		OPENBLAS_CORETYPE MKL_CBWR ATEN_CPU_CAPABILITY ONEDNN_MAX_CPU_ISA \
		DNNL_MAX_CPU_ISA
	fakebin=$(mktemp -d "${BATS_TMPDIR:-/tmp}/reproseed.XXXXXX")
}

teardown() {
	rm -rf "$fakebin"
}

# fake NAME BODY: create command NAME running shell BODY, for run_faked
fake() {
	printf '#!/bin/sh\n%s\n' "$2" > "$fakebin/$1"
	chmod +x "$fakebin/$1"
}

# run reproseed with fake commands first in PATH, and print environment
run_faked() {
	PATH="$fakebin:$PATH" $REPROSEED_CMD env 2>&1
}

# fake_cpuinfo FLAGS: make reproseed grep a fake /proc/cpuinfo with FLAGS
fake_cpuinfo() {
	echo "flags		: $1" > "$fakebin/cpuinfo"
	fake grep "exec $(command -v grep) \"\$1\" \"\$2\" '$fakebin/cpuinfo'"
}

refute_cpu_vars() {
	! echo "$1" | grep -qE "$CPU_VARS_RE"
}

@test "source basic functionality test" {
	. $REPROSEED_CMD
	common_checks "$REPROSEED"
}

@test "source check output" {
 	out=$(. $REPROSEED_CMD 2>&1)
 	echo "$out" | grep -q '(random)'
}

@test "seed and source" {
 	REPROSEED=1 . $REPROSEED_CMD
	eval common_checks 1
}

@test "execute" {
 	out=$($REPROSEED_CMD export 2>&1 | grep SEED)
	echo "$out" | grep -q '(random)'
	echo "$out" | grep -q 'AFNI_RANDOM_SEEDVAL'
}

@test "seed execute" {
 	out=$(REPROSEED=1 $REPROSEED_CMD export 2>&1 | grep SEED)
	echo "$out" | grep -q 'REPROSEED=1 (provided)'
	echo "$out" | grep -q "AFNI_RANDOM_SEEDVAL='1'"
}

@test "no output to stdout" {
	[ -z "$(. $REPROSEED_CMD 2>/dev/null)" ]
	[ -z "$($REPROSEED_CMD true 2>/dev/null)" ]
}

@test "cpu features restricted by default on x86_64" {
	case "$(uname -m)" in x86_64) ;; *) skip "not x86_64";; esac
	. $REPROSEED_CMD
	[ "$REPROSEED_CPU" = "x86-64-v3" ]
	[ "$MKL_CBWR" = "AVX2" ]
	[ "$ONEDNN_MAX_CPU_ISA" = "AVX2" ]
	if grep -qw avx512f /proc/cpuinfo; then
		echo "$NPY_DISABLE_CPU_FEATURES" | grep -qw AVX512_SKX
	fi
	if grep -qw avx2 /proc/cpuinfo && grep -qw fma /proc/cpuinfo; then
		[ "$OPENBLAS_CORETYPE" = "Haswell" ]
		[ "$ATEN_CPU_CAPABILITY" = "avx2" ]
	fi
}

@test "cpu features values" {
	fake uname 'echo x86_64'
	fake_cpuinfo 'avx avx2 fma avx512f'
	out=$(run_faked)
	echo "$out" | grep -qx 'REPROSEED_CPU=x86-64-v3'
	echo "$out" | grep -qx 'NPY_DISABLE_CPU_FEATURES=AVX512F AVX512_SKX AVX512_ICL AVX512_SPR X86_V4'
	echo "$out" | grep -qx 'OPENBLAS_CORETYPE=Haswell'
	echo "$out" | grep -qx 'MKL_CBWR=AVX2'
	echo "$out" | grep -qx 'ATEN_CPU_CAPABILITY=avx2'
	echo "$out" | grep -qx 'ONEDNN_MAX_CPU_ISA=AVX2'
	echo "$out" | grep -qx 'DNNL_MAX_CPU_ISA=AVX2'
	[ "$(echo "$out" | grep -c '^W:')" -eq 0 ]
}

@test "cpu features not forced if CPU support is not confirmed" {
	fake uname 'echo x86_64'
	for flags in 'avx avx2 fma4' 'avx fma'; do
		fake_cpuinfo "$flags"
		out=$(run_faked)
		echo "$out" | grep -q 'W: could not confirm that CPU supports x86-64-v3 (AVX2, FMA), not setting OPENBLAS_CORETYPE ATEN_CPU_CAPABILITY;'
		echo "$out" | grep -qx 'MKL_CBWR=AVX2'
		echo "$out" | grep -qx 'ONEDNN_MAX_CPU_ISA=AVX2'
		[ "$(echo "$out" | grep -cE '^(OPENBLAS_CORETYPE|ATEN_CPU_CAPABILITY)=')" -eq 0 ]
	done
}

@test "cpu features not restricted if native" {
	fake uname 'echo x86_64'
	out=$(REPROSEED_CPU=native run_faked)
	echo "$out" | grep -qx 'REPROSEED_CPU=native'
	refute_cpu_vars "$out"
}

@test "cpu features not restricted by default on non-x86_64" {
	fake uname 'echo aarch64'
	out=$(run_faked)
	echo "$out" | grep -qx 'REPROSEED_CPU=native'
	refute_cpu_vars "$out"
}

@test "x86-64-v3 on non-x86_64 warns" {
	fake uname 'echo aarch64'
	out=$(REPROSEED_CPU=x86-64-v3 run_faked)
	echo "$out" | grep -q 'W: REPROSEED_CPU=x86-64-v3 is not supported on aarch64'
	refute_cpu_vars "$out"
}

@test "unknown cpu level warns" {
	fake uname 'echo x86_64'
	out=$(REPROSEED_CPU=bogus run_faked)
	echo "$out" | grep -q 'W: REPROSEED_CPU=bogus is not supported on x86_64'
	refute_cpu_vars "$out"
}

@test "NumPy is not restricted without AVX512" {
	[ -r /proc/cpuinfo ] || skip "no /proc/cpuinfo"
	fake uname 'echo x86_64'
	fake_cpuinfo 'avx avx2 fma'
	out=$(run_faked)
	echo "$out" | grep -qx 'MKL_CBWR=AVX2'
	[ "$(echo "$out" | grep -c '^NPY_DISABLE_CPU_FEATURES=')" -eq 0 ]
}

@test "NumPy is not restricted if NPY_ENABLE_CPU_FEATURES is set" {
	fake uname 'echo x86_64'
	fake_cpuinfo 'avx avx2 fma avx512f'
	out=$(NPY_ENABLE_CPU_FEATURES=X86_V3 run_faked)
	echo "$out" | grep -qx 'MKL_CBWR=AVX2'
	[ "$(echo "$out" | grep -c '^NPY_DISABLE_CPU_FEATURES=')" -eq 0 ]
}

@test "cpu variables set by the caller are kept, even if empty" {
	fake uname 'echo x86_64'
	fake_cpuinfo 'avx'
	out=$(MKL_CBWR=COMPATIBLE OPENBLAS_CORETYPE='' run_faked)
	echo "$out" | grep -qx 'MKL_CBWR=COMPATIBLE'
	echo "$out" | grep -qx 'OPENBLAS_CORETYPE='
	echo "$out" | grep -q 'not setting ATEN_CPU_CAPABILITY;'
	[ "$(echo "$out" | grep -c '^W:.*OPENBLAS_CORETYPE')" -eq 0 ]
}

@test "source under set -eu" {
	fake uname 'echo x86_64'
	out=$(PATH="$fakebin:$PATH" sh -c "set -eu; REPROSEED=1; . $REPROSEED_CMD; echo MKL_CBWR=\$MKL_CBWR")
	echo "$out" | grep -qx 'MKL_CBWR=AVX2'
}

@test "cpu warnings go to stderr only" {
	fake uname 'echo x86_64'
	fake_cpuinfo 'avx avx512f'
	[ -z "$(PATH="$fakebin:$PATH" $REPROSEED_CMD true 2>/dev/null)" ]
	[ -z "$(PATH="$fakebin:$PATH" REPROSEED_CPU=bogus $REPROSEED_CMD true 2>/dev/null)" ]
}
