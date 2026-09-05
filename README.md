# Post-processing of RSoft extraction-efficiency sweeps

MATLAB scripts for calculating the extraction efficiency from spatial power-monitor files exported by RSoft. The scripts were developed for the numerical optimization of Bullseye structures with and without a distributed Bragg reflector.

## Scripts

- `single_parameter_sweep.m` calculates the extraction efficiency for a set of simulations in which one parameter is varied. It generates an extraction-efficiency curve, identifies the optimum and exports the resulting figure.

- `double_parameter_sweep.m` processes a two-dimensional sweep in which two parameters are varied simultaneously. It generates an efficiency map, identifies the joint optimum and exports the map as CSV, MATLAB figure and vector PDF.

## Extraction-efficiency calculation

For each simulation, the scripts read the normal power density on a two-dimensional spatial monitor. The extraction efficiency is evaluated numerically as

\begin{equation}
\eta_{\mathrm{ext}} \approx f_{\mathrm{sym}}
\sum_{i,j} P_{ij} M_{ij}\Delta x\Delta y,
\end{equation}

where \(P_{ij}\) is the power density at each monitor point, \(M_{ij}\) is the circular collection mask, \(f_{\mathrm{sym}}\) is the symmetry factor, and \(\Delta x\) and \(\Delta y\) are the monitor-grid spacings.

The reported value corresponds to a power fraction when the RSoft simulation is normalized to unit launched power.

## Input data

The scripts expect RSoft spatial-monitor files in `.dat` format. Each file must contain the grid dimensions and coordinate limits in its metadata, followed by the two-dimensional power-density grid.

The expected filenames are:

```text
# Single-parameter sweep
<tag>_<index>_m13_f1_pow.dat

# Double-parameter sweep
<tag>_<index_parameter_1>_<index_parameter_2>_m13_f1_pow.dat
```

For double sweeps, the order of the indices must match the order used in the RSoft parameter sweep.

## Requirements

- MATLAB R2020a or later.
- RSoft output files generated from a spatial power monitor.
- No additional MATLAB toolboxes are required.

## Usage

1. Place the RSoft output files in a local `data/` directory.
2. Set the sweep parameters, filename tag and monitor label in the configuration block at the beginning of the relevant script.
3. Run the script in MATLAB.
4. Enter the symmetry factor corresponding to the simulated fraction of the structure.
5. Find the exported figures and numerical data in `results/`.

Raw simulation data are not included in this repository. A small anonymized example dataset may be added in `example_data/` to demonstrate the expected file format.

## Citation

If you use this code, please cite the archived software release indicated in `CITATION.cff`.

## License

This project is distributed under the MIT License.
