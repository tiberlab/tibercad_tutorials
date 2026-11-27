# Example 29: Multiphysics Degradation Model for Perovskite Photovoltaic Modules

This folder contains the reference TiberCAD input decks, post-processing utilities, NOMAD database extraction and filtering scripts, processed datasets, and MATLAB analysis routines accompanying the work:

> **Multiphysics Degradation Modeling and NOMAD Validation for Photooxidative Stability of Perovskite Photovoltaic Modules**  
> Alessia Di Vito and Matthias Auf der Maur (*Solar Energy*, Elsevier)

---

## Folder Contents

### 1. TiberCAD Finite-Element and SPICE Input Files (Root Directory)
- `module.geo` / `module.msh`: Gmsh 2D finite-element geometry and mesh for the 5-cell monolithically series-connected perovskite mini-module ($10.0\text{ cm}^2$ active area, $5.0\text{ mm}$ perimeter edge seal).
- `module.tib`: Reference TiberCAD input file coupling 2D Fickian gas diffusion ($\text{O}_2$, $\text{H}_2\text{O}$), photo-oxidation reaction kinetics, and the distributed SPICE equivalent-circuit network.
- `reference/`: Reference simulation output files.

### 2. Post-Processing, NOMAD Meta-Analysis, and Plotting (`scripts/`)
- **NOMAD Extraction & Bash Post-Processing:**
  - `nomad_psc_exporter.py`: Python script querying the FAIRmat NOMAD Perovskite Solar Cell Database REST API.
  - `process_lifetime_scatter.py`: Python script performing PRISMA screening, encapsulant classification, and extraction of time--efficiency degradation points.
  - `pp_modules.sh`: Bash/AWK post-processing script extracting macroscopic module electrical parameters ($I_{\text{sc}}, V_{\text{oc}}, P_{\max}, \text{FF}, \text{PCE}$) from TiberCAD `sweep_pv.dat` outputs.
- **Processed Datasets (`.csv`):**
  - `lifetime_scatter_points.csv` and `nomad_enriched_546_points_with_metadata.csv`: Extracted and categorized NOMAD experimental stability dataset ($302$ encapsulated entries, $546$ discrete time--efficiency points).
  - `risultati_tibercad_sensitivita_320K.csv`: Complete electrical outputs and extracted $T_{80}$ lifetimes across the $27$ TiberCAD multiphysics sensitivity simulations ($3$ nominal baselines and $24$ parameter perturbations at $320\text{ K}, 50\%\text{ RH}$).
  - `risultati_tibercad_benchmarks_lungo_termine.csv`: TiberCAD simulation results for the four multi-thousand-hour NOMAD experimental benchmarks (`BM1`, `BM2A`, `BM2B`, `BM3`, $1000\text{--}5300\text{ h}$).
  - `real_vtu_spatial_profiles.csv`: Extracted 2D centerline spatial profiles of $\text{O}_2$ and $\text{H}_2\text{O}$ partial pressures, dissolved concentrations, and active perovskite fraction.
  - `tibercad_electrical_decomposition.csv`: Module $I\text{--}V$ parameters and logarithmic variance decomposition into $\Delta I_{\text{sc}}, \Delta V_{\text{oc}}$, and $\Delta\text{FF}$.
- **MATLAB Analysis & Plotting Routines (`.m`):**
  - `step1_sensitivity_cira_preprocessing.m`: Analytical partial-derivative sensitivity, first-order Taylor error propagation on $r_{\text{total}}$, and plotting of the 27 TiberCAD sensitivity runs.
  - `step2_concentration_profiles_and_degradation.m`: Visualization of 2D lateral gas concentration profiles and active perovskite fraction evolution.
  - `step3_nomad_meta_analysis_stats_and_zoom_plots.m`: One-Way ANOVA variance decomposition, multivariate subgroup stratification, envelope coverage audit, and long-term benchmark comparison.
  - `step4_decouple_Jsc_Voc_FF_Rs.m`: Analytical and numerical decomposition of module efficiency decay across series-connected sub-cells.
