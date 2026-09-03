# Errata

This repository includes a formal errata for Dylan Jacob Gormley's May 2021 thesis, *A Low-Memory Spectral-Correlation Analyzer for Digital QAM-SRRC Waveforms*.

- Editable source: `errata/errata.tex`
- Printable document: `output/pdf/msee-thesis-2021-errata.pdf`
- Corrected thesis: `output/pdf/msee-thesis-2021.pdf`

The errata uses the deposited thesis's printed page numbers and Arabic table labels (OhioLINK accession `csu1622636550863441`). The corrected thesis formats original Tables 10--13 as Tables X--XIII. Section, equation, figure, and table identifiers govern if another copy has different pagination. Minor editorial changes are summarized by category; substantive mathematical, experimental, implementation, and toolchain corrections are itemized.

To rebuild the standalone document:

```sh
cd errata
latexmk -pdf errata.tex
```
