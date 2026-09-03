# A Low-Memory Spectral-Correlation Analyzer for Digital QAM-SRRC Waveforms

This repository contains the maintained, reproducible edition of Dylan Jacob
Gormley's May 2021 M.S.E.E. thesis, its errata, the MATLAB sources for the
maintained plots, and the implementation material needed to audit the design.

## Canonical documents

- `main.tex` is the thesis entry point and the **Main document** to select in
  Overleaf.
- `errata/errata.tex` is the standalone errata source.
- `output/pdf/msee-thesis-2021.pdf` and
  `output/pdf/msee-thesis-2021-errata.pdf` are the only canonical release PDFs.

The committed PDFs make the corrected edition easy to read without requiring a
local TeX installation. Rebuild them before a release so they agree with the
tracked sources.

## Repository layout

| Path | Role |
| --- | --- |
| `main.tex` | Root thesis document and Overleaf entry point |
| `tex/` | Shared preamble, notation, and document-format definitions |
| `sections/` | Thesis front matter, chapters, appendices, and bibliography |
| `images/diagrams/tikz/` | Maintained, source-controlled DSP/FPGA diagrams |
| `images/plots/` | MATLAB-generated plots used by the thesis |
| `images/characterization/` | Fixed experiment figures used by Chapter IV |
| `matlab/` | Plot orchestrator, reusable numerical functions, and tests |
| `errata/` | Standalone errata source |
| `supporting-materials/characterization/` | Fixed characterization evidence package and checksum |
| `supporting-materials/spectrum-sensor/` | Integrity-verifiable RTL, tests, models, and Vivado project sources |
| `legacy/` | Superseded material retained for historical reference |
| `output/pdf/` | Canonical release PDFs only |
| `build/` | Ignored local TeX intermediates |

## Toolchain

The maintained MATLAB figures target **MATLAB R2025b** with Signal Processing
Toolbox and Communications Toolbox. `matlab/generate_all_plots.m` is the public
orchestrator; individual figure families are functions under
`matlab/+thesis/+figures/`, while shared signal processing and plotting code is
under `matlab/+thesis/+signal/` and `matlab/+thesis/+plot/`.

The documents build with `latexmk` and pdfLaTeX. The current edition has been
verified with TeX Live 2023 and is also arranged for a root-document Overleaf
build. A current TeX Live installation containing the packages imported by
`main.tex` and `errata/errata.tex` is sufficient.

The component project sources record **Vivado 2019.2.1**, the
`xc7z020clg484-1` device, and the ZedBoard board definition
`em.avnet.com:zed:part0:1.4`. Vivado is not needed to build the thesis PDFs; it
is needed only to recreate or simulate those FPGA components. See
`supporting-materials/spectrum-sensor/README.md` for the exact source-package
scope and provenance.

## Common commands

Run these commands from the repository root:

```sh
make figures       # regenerate every maintained MATLAB plot
make matlab-test   # run the numerical MATLAB test suite
make thesis        # build build/thesis/main.pdf
make errata        # build build/errata/errata.pdf
make verify        # test MATLAB, validate evidence, and build both documents
make release       # regenerate plots, verify, then write the canonical PDFs
make clean         # remove the ignored build directory
```

`MATLAB` and `LATEXMK` may be overridden when those executables are not on
`PATH`, for example `make MATLAB=/path/to/matlab figures`.

## Generated and fixed material

The PNG files under `images/plots/` are generated outputs. They are tracked so
Overleaf can compile the thesis without MATLAB, but their maintained source is
the code under `matlab/`. Regenerate them with `make figures`; do not hand-edit
the PNGs.

The experiment images under `images/characterization/` and the supporting
packages under `supporting-materials/` are fixed evidence. They are not outputs
of the current MATLAB figure pipeline. Keep their bytes unchanged. The
supporting packages have SHA-256 manifests for independent verification. In
particular, the available characterization material does not provide a
complete raw-results-to-PNG pipeline for every experiment figure; that
limitation is documented in `supporting-materials/characterization/README.md`.

Files under `legacy/` are intentionally excluded from active builds. New work
should update the maintained sources rather than reintroducing a legacy raster
diagram or draft.
