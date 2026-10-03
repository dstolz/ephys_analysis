"""Golden values for pAdjust, computed with statsmodels' multipletests.

Each case is a vector of p values (stored as they are: a JSON number is read
back as the same double) and its adjusted values for "bh" (fdr_bh), "holm"
and "bonferroni". A NaN (JSON null) is not a test: the other values are
adjusted as a family of their own, as R's p.adjust treats NA, and the NaN
stays where it was. test_ResponseStats compares pAdjust with these:
pipeline/testdata/padjust_golden.json.

    python tools/golden/padjust_golden.py      # needs numpy, statsmodels

Regenerate only on purpose; the file records the versions it came from.
"""
import json, math
from pathlib import Path
import numpy as np
import statsmodels
from statsmodels.stats.multitest import multipletests

METHODS = {"bh": "fdr_bh", "holm": "holm", "bonferroni": "bonferroni"}

rng = np.random.default_rng(20261003)
cases = {
    "uniform20": rng.uniform(0, 1, 20).tolist(),
    "small_and_large": [1e-10, 2e-10, 0.001, 0.049, 0.051, 0.2, 0.9],
    "ties": [0.01, 0.01, 0.04, 0.04, 0.2, 0.5, 0.5, 1.0],
    "unsorted": [0.9, 0.001, 0.04, 0.03, 0.2, 0.0001],
    "near_one": [0.6, 0.7, 0.8, 0.9, 0.95],
    "single": [0.03],
    "with_nan": [0.02, math.nan, 0.03, math.nan, 0.5, 0.001],
    "skewed200": np.concatenate([rng.uniform(0, 1e-3, 40), rng.uniform(0, 1, 160)]).tolist(),
}

out = {"source": "statsmodels.stats.multitest.multipletests",
       "versions": {"statsmodels": statsmodels.__version__, "numpy": np.__version__},
       "cases": []}
for name, p in cases.items():
    p = np.asarray(p, dtype=float)
    ok = ~np.isnan(p)
    case = {"name": name, "p": [None if math.isnan(v) else v for v in p.tolist()]}
    for key, method in METHODS.items():
        q = np.full(p.shape, np.nan)
        q[ok] = multipletests(p[ok], method=method)[1]
        case[key] = [None if math.isnan(v) else v for v in q.tolist()]
    out["cases"].append(case)

dest = Path(__file__).resolve().parents[2] / "pipeline" / "testdata" / "padjust_golden.json"
dest.write_text(json.dumps(out, indent=1) + "\n")
print(f"wrote {dest}")
