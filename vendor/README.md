# Vendored dependencies

This pipeline was split out of `helper_fnc`'s `ephys/` folder, but it still
calls a handful of general-purpose utilities that live elsewhere in
`helper_fnc`. Rather than depend on `helper_fnc` being on the MATLAB path,
those files were copied here as of 2026-09-11 (from `helper_fnc` at commit
`61611a9`) so this repo is self-contained.

These are **snapshots, not synced copies** — changes to the originals in
`helper_fnc` will not propagate here, and changes here will not propagate
back. If a bug is fixed in one copy, check whether the other needs the same
fix.

| File here | Origin in `helper_fnc` | Used by |
| --- | --- | --- |
| [`tools/Manifest.m`](tools/Manifest.m) | `tools/Manifest.m` | `EphysDataset.Manifest` (optional provenance log) |
| [`compute/parfor_progress.m`](compute/parfor_progress.m) | `compute/parfor_progress.m` | `intan2matlab` console progress bar |
| [`function_helpers/ternary.m`](function_helpers/ternary.m) | `function_helpers/ternary.m` | `DatasetTracker` |
