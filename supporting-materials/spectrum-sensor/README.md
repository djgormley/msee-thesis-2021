# Spectrum sensor supporting materials

This directory keeps the implementation and modeling files used alongside the thesis in the same version-controlled repository. The [maintained MATLAB figure sources](../../matlab/) remain authoritative for the thesis figures and Appendix A. The files under `source/` preserve the corresponding component-development material for traceability, reruns, and future technical review.

## Included material

- VHDL sources and testbenches for the XC7Z020 component flow described in Chapters III and IV
- Python generators and result-checking scripts used by the component tests
- MATLAB live scripts for the SCA model and FIR coefficient generation, with plain-text `.m` exports beside each `.mlx` file
- Vivado component project-recreation scripts
- NCO coefficient tables and compact fixed-point regression vectors
- WaveDrom JSON used to define the component timing diagrams

The component project scripts record Vivado 2019.2.1, part `xc7z020clg484-1`, and ZedBoard board definition `em.avnet.com:zed:part0:1.4`. Relative paths are preserved because the scripts refer to neighboring component directories.

## Layout and use

The tree below `source/` follows the supplied project layout. Run a component's generator, testbench helper, or project script from that component directory so its relative paths resolve as designed.

Several VHDL testbenches retain the Windows paths used by their file-I/O statements. Set those paths for the local checkout before running the associated simulation. The Python helpers use NumPy, SciPy, and Matplotlib. The MATLAB sources use Signal Processing Toolbox and Communications Toolbox functions.

The `.m` files beside the live scripts are plain-text exports made with MATLAB R2025b. They preserve the live-script code for review and version diffs; the `.mlx` files remain the byte-identical source records from the inventory package.

## Provenance and integrity

`SOURCE.json` records the package identity, repository reference, target platform, selection scope, and MATLAB export hashes. `MANIFEST.sha256` covers every tracked file in this directory except the manifest itself.

The supplied source inventory did not contain a `LICENSE`, `NOTICE`, or SPDX license grant. Existing authorship and copyright headers are preserved, and this directory does not add or change license terms.

## Material kept outside this set

The selection omits generated Xilinx FFT HDL, netlists, checkpoints, C models, and other build products; nested Git metadata; Office and Visio documents; debug screenshots and waveform captures; and older test material. The FFT configuration in the inventory targets an XCKU5P/Kintex UltraScale+ Cesium platform with Vivado 2019.1.3, so it is not part of the thesis's XC7Z020/ZedBoard source set. Later integration files that depend on that platform are likewise kept separate from these thesis-support sources.
