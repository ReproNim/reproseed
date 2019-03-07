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

while read _toolkit _var_more; do
    _var=${_var_more%% *}
    _more=${_var_more#* }
    eval export $_var="$REPROSEED" $_more
    _setfor="$_setfor $_toolkit"
done << EOF
AFNI AFNI_RANDOM_SEEDVAL
ANTs ANTS_RANDOM_SEED
PyMVPA MVPA_SEED
GSL GSL_RNG_SEED GSL_RNG_TYPE="taus"
EOF

export REPROSEED
echo "I: REPROSEED=$REPROSEED ($_reproseed_src) set for $_setfor"

if [ "$#" -gt 0 ]; then
    echo "I: reproseed.sh - running $@"
    "$@"
fi
