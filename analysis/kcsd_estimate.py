"""kcsd_estimate.py  Run kCSD-python on the arrays kcsdEstimate.m wrote.

    python kcsd_estimate.py <in.npz> <out.npz>

One run takes any number of profiles ("jobs"), so a session's shanks cost one
Python start, not one each. in.npz holds n_jobs and, for job i = 1 .. n_jobs,
ele_pos_i [n x dim] (mm), pots_i [n x nTime] (mV) and params_i, a JSON
string: the estimator's keyword arguments (sigma, h, n_src_init, R_init, gdx,
gdy, ext_x, ext_y, xmin, xmax, ymin, ymax, lambd, src_type), plus
"cv_lambdas" / "cv_Rs" (arrays: cross-validate over them when either is
given), "l_curve" (true: pick lambda and R by the L-curve over the same
arrays) and "source_path" (a folder to import kcsd from, when it is not
installed). out.npz gets, for each job i, csd_i (ngx x nTime, or ngx x ngy x
nTime), estm_x_i, estm_y_i, lambd_i, R_i, pot_est_i (the fitted potentials
at the electrodes), n_src_i, seconds_i (the job's time here), and with a
cross-validation cv_lambdas_i, cv_Rs_i and cv_errors_i [nRs x nLambdas].
A failure prints "KCSD_ERROR: <message>" (naming the job) and exits 1; a
good run ends with "KCSD_OK".

kCSD-python's validation module still imports scipy.integrate.simps, gone
in SciPy 1.14: the alias is put back before the import.
"""
import json
import sys
import time
import traceback


def estimate(np, KCSD1D, KCSD2D, ele_pos, pots, params):
    """One profile: the arrays of out.npz for it (without the job number)."""
    ele_pos = np.asarray(ele_pos, dtype=float)
    pots = np.asarray(pots, dtype=float)
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
    return out


def main(src, dst):
    import numpy as np
    d = np.load(src)
    n_jobs = int(d["n_jobs"])
    params = [json.loads(str(d["params_%d" % i])) for i in range(1, n_jobs + 1)]
    source_path = ""
    for p in params:
        source_path = p.pop("source_path", "") or source_path
    if source_path:
        sys.path.insert(0, source_path)
    import scipy.integrate
    if not hasattr(scipy.integrate, "simps"):
        scipy.integrate.simps = scipy.integrate.simpson
    from kcsd import KCSD1D, KCSD2D

    out = {}
    for i in range(1, n_jobs + 1):
        t = time.perf_counter()
        try:
            res = estimate(np, KCSD1D, KCSD2D, d["ele_pos_%d" % i], d["pots_%d" % i], params[i - 1])
        except Exception as exc:   # noqa: BLE001 - say which profile failed
            raise RuntimeError("profile %d of %d: %s: %s" % (i, n_jobs, type(exc).__name__, exc)) from exc
        res["seconds"] = time.perf_counter() - t
        for name, value in res.items():
            out["%s_%d" % (name, i)] = value
        print("KCSD_JOB %d lambd=%g R=%g n_src=%d" % (i, res["lambd"], res["R"], res["n_src"]))
    np.savez(dst, **out)
    print("KCSD_OK jobs=%d" % n_jobs)


if __name__ == "__main__":
    try:
        main(sys.argv[1], sys.argv[2])
    except Exception as exc:   # noqa: BLE001 - report everything to MATLAB
        traceback.print_exc()
        print("KCSD_ERROR: %s: %s" % (type(exc).__name__, exc))
        sys.exit(1)
