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
display that seed (so you could use it later to reproduce the
results), and export corresponding environment variables with its
value for other tools it is aware about (e.g., PyMVPA, AFNI, ANTs).

## HOWTO

Just download `reproseed.sh` to your computer or install within your
container, and either

- `source reproseed.sh` (or `. reproseed.sh`) in your script before
  running your computation
- execute your computation script via `reproseed`, e.g.

    ./reproseed.sh myscript -param1 arg1
