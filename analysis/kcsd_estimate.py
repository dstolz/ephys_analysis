"""kcsd_estimate.py  Run kCSD-python on the arrays kcsdEstimate.m wrote.

    python kcsd_estimate.py <in.npz> <out.npz>

in.npz holds ele_pos [n x dim] (mm), pots [n x nTime] (mV) and params, a
JSON string: the estimator's keyword arguments (sigma, h, n_src_init,
R_init, gdx, gdy, ext_x, ext_y, xmin, xmax, ymin, ymax, lambd, src_type),
plus "cv_lambdas" / "cv_Rs" (arrays: cross-validate over them when
either is given), "l_curve" (true: pick lambda and R by the L-curve over
the same arrays) and "source_path" (a folder to import kcsd from, when it
is not installed). out.npz gets csd (ngx x nTime, or ngx x ngy x nTime),
estm_x, estm_y, lambd, R, pot_est (the fitted potentials at the
electrodes), and with a cross-validation cv_lambdas, cv_Rs and cv_errors
[nRs x nLambdas]. Failures print "KCSD_ERROR: <message>" and exit 1.

kCSD-python's validation module still imports scipy.integrate.simps, gone
in SciPy 1.14: the alias is put back before the import.
"""
import json
import sys
import traceback


def main(src, dst):
    import numpy as np
    d = np.load(src)
    params = json.loads(str(d["params"]))
    source_path = params.pop("source_path", "")
    if source_path:
        sys.path.insert(0, source_path)
    import scipy.integrate
    if not hasattr(scipy.integrate, "simps"):
        scipy.integrate.simps = scipy.integrate.simpson
    from kcsd import KCSD1D, KCSD2D

    ele_pos = np.asarray(d["ele_pos"], dtype=float)
    pots = np.asarray(d["pots"], dtype=float)
    if ele_pos.ndim == 1:
        ele_pos = ele_pos.reshape(-1, 1)
    if pots.ndim == 1:
        pots = pots.reshape(-1, 1)
    l_curve = bool(params.pop("l_curve", False))
    do_cv = ("cv_lambdas" in params) or ("cv_Rs" in params) or l_curve
    cv_lambdas = params.pop("cv_lambdas", None)
    cv_Rs = params.pop("cv_Rs", None)
    if cv_lambdas is not None and np.size(cv_lambdas) == 0:
        cv_lambdas = None                      # [] from MATLAB: kCSD's own default
    if cv_Rs is not None and np.size(cv_Rs) == 0:
        cv_Rs = None
    kwargs = {k: v for k, v in params.items() if v is not None}
    for k in ("n_src_init", "dist_table_density"):
        if k in kwargs:
            kwargs[k] = int(kwargs[k])

    dim = ele_pos.shape[1]
    if dim == 1:
        k = KCSD1D(ele_pos, pots, **kwargs)
    elif dim == 2:
        k = KCSD2D(ele_pos, pots, **kwargs)
    else:
        raise ValueError("ele_pos must have 1 or 2 columns, not %d" % dim)

    out = {}
    if do_cv:
        lambdas = None if cv_lambdas is None else np.atleast_1d(np.asarray(cv_lambdas, dtype=float))
        Rs = None if cv_Rs is None else np.atleast_1d(np.asarray(cv_Rs, dtype=float))
        if Rs is None:
            Rs = np.atleast_1d(np.asarray(k.R, dtype=float))
        if l_curve:
            if lambdas is None:
                lambdas = np.logspace(-10, -1, 100, base=10)       # L_curve's own default
            k.L_curve(lambdas=lambdas, Rs=Rs)
            out["cv_errors"] = np.asarray(k.curve_surf, dtype=float)   # [nRs x nLambdas], larger = better
        else:
            if lambdas is None:
                lambdas = np.hstack((np.logspace(-2, -25, 25, base=10.0), [0.0]))   # cross_validate's own default
            k.cross_validate(lambdas=lambdas, Rs=Rs)
            out["cv_errors"] = np.asarray(k.errs, dtype=float)         # [nRs x nLambdas], smaller = better
        out["cv_lambdas"] = lambdas
        out["cv_Rs"] = Rs

    csd = k.values("CSD")
    out["csd"] = np.asarray(csd, dtype=float)
    if dim == 1:
        out["estm_x"] = np.asarray(k.estm_x, dtype=float).reshape(-1)
    else:   # meshgrid(x, y, indexing="ij"): x varies down axis 0, y along axis 1
        out["estm_x"] = np.asarray(k.estm_x[:, 0], dtype=float)
        out["estm_y"] = np.asarray(k.estm_y[0, :], dtype=float)
    out["lambd"] = float(k.lambd)
    out["R"] = float(k.R)
    # the fitted potentials at the electrodes: k_pot @ beta
    kernel = k.k_pot + k.lambd * np.identity(k.k_pot.shape[0])
    beta = np.linalg.solve(kernel, k.pots)
    out["pot_est"] = np.asarray(k.k_pot @ beta, dtype=float)
    out["n_src"] = int(k.n_src)
    np.savez(dst, **out)
    print("KCSD_OK lambd=%g R=%g n_src=%d" % (k.lambd, k.R, k.n_src))


if __name__ == "__main__":
    try:
        main(sys.argv[1], sys.argv[2])
    except Exception as exc:   # noqa: BLE001 - report everything to MATLAB
        traceback.print_exc()
        print("KCSD_ERROR: %s: %s" % (type(exc).__name__, exc))
        sys.exit(1)
