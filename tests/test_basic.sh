#!/bin/sh

# export PATH=$(dirname $0/..):$PATH
REPROSEED_CMD="../reproseed.sh"

testSource()
{
	. $REPROSEED_CMD
	assertEquals "$AFNI_RANDOM_SEEDVAL" "$REPROSEED"
	assertEquals "$MVPA_SEED" "$REPROSEED"
}

testSourceOutput() {
	out=`. $REPROSEED_CMD`
	#assertTrue "echo $out | grep -q '(random)'"
	assertContains '(random)' "$out"
}

testSourceSeeded()
{
	REPROSEED=1 . $REPROSEED_CMD
	assertEquals "$REPROSEED" 1
	assertEquals "$AFNI_RANDOM_SEEDVAL" "$REPROSEED"
	assertEquals "$MVPA_SEED" "$REPROSEED"
}

. shunit2
