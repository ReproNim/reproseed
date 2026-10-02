#!/usr/bin/env bats

# export PATH=$(dirname $0/..):$PATH
REPROSEED_CMD="./reproseed.sh"

common_checks() {
	# Common checks to see if all seeds in the environment are equal
	# to the desired value
	[ "$REPROSEED" = "$1" ]
	[ "$AFNI_RANDOM_SEEDVAL" = "$REPROSEED" ]
	[ "$MVPA_SEED" = "$REPROSEED" ]

}

@test "source basic functionality test" {
	. $REPROSEED_CMD
	common_checks "$REPROSEED"
}

@test "source check output" {
 	out=`. $REPROSEED_CMD 2>&1`
 	echo $out | grep -q '(random)'
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
