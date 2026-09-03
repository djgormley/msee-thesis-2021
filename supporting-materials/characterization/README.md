# Characterization evidence

This directory contains the fixed evidence package associated with the
experiment characterization reported in Chapter IV.

`characterization-tests.zip` contains supplied waveform-generation code,
experiment notes, and fixed-point input and result text files. Treat the ZIP as
an immutable record. It is not a dependency of the normal thesis, errata, or
MATLAB-figure builds.

The active `exp1.png` through `exp13.png` figures remain in
`../../images/characterization/` because the thesis includes them directly.
Those PNGs are fixed result figures rather than products of the maintained
`matlab/generate_all_plots.m` pipeline.

## Reproduction boundary

The available package preserves useful experiment inputs, notes, and results,
but it does not provide a complete, documented raw-results-to-PNG procedure for
all thirteen active experiment figures. In particular, the package is not a
one-command source for rebuilding `exp1.png` through `exp13.png`. Accordingly,
the committed PNGs are the authoritative figures for the corrected edition,
and the ZIP supports auditing rather than automatic figure regeneration.

## Integrity

`MANIFEST.sha256` records the byte identity of the fixed ZIP. From this
directory, validate it with:

```sh
sha256sum --check MANIFEST.sha256
```

The expected result is:

```text
characterization-tests.zip: OK
```

The archive can be inventoried without modifying it:

```sh
unzip -l characterization-tests.zip
```
