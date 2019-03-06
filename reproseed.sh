#!/bin/sh
# A mighty POSIX shell script to be used to preseed computational
# tools (original domain - neuroimaging) with a specified and/or
# displayed seed for RNG, so that results have higher chance to be
# identical if recomputed if the same seed is provided
#
# TODOs:
#   FreeSurfer -- seems no env var, reconall takes -norandomness or 
#   ... more!? -- please send a PR

if [ -z "$REPROSEED" ]; then
    REPROSEED=$(bash -c 'echo $RANDOM')
    _reproseed_src="random"
else
    _reproseed_src="provided"
fi

_setfor=""

while read _var _toolkit; do
    eval export $_var="$REPROSEED"
    _setfor="$_setfor $_toolkit"
done << EOF
AFNI_RANDOM_SEEDVAL AFNI
ANTS_RANDOM_SEED ANTs
MVPA_SEED PyMVPA
EOF

export REPROSEED
echo "I: REPROSEED=$REPROSEED ($_reproseed_src) set for $_setfor"

if [ "$#" -gt 0 ]; then
    echo "I: reproseed.sh - running $@"
    "$@"
fi
