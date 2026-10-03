"""Golden values for unitQualityMetrics, computed with SpikeInterface.

The spike trains, amplitudes and positions come from a Lehmer generator
(x <- 16807 x mod 2^31-1) and sums of its uniforms, using only exact or
correctly rounded double arithmetic, so test_UnitQuality builds the very same
values in MATLAB and only the expected metrics need storing:
pipeline/testdata/unit_quality_golden.json. Each metric runs through
SpikeInterface's own compute_* function (bin edges, NaN rules): the
amplitudes and y positions are injected into a SortingAnalyzer's
spike_amplitudes and spike_locations extensions.

    python tools/golden/unit_quality_golden.py      # needs spikeinterface, scipy

Regenerate only on purpose; the file records the versions it came from.
"""
import json, warnings
from pathlib import Path
import numpy as np
import scipy
import spikeinterface
import spikeinterface.core as sc
from scipy.ndimage import gaussian_filter1d
from spikeinterface.metrics.quality import misc_metrics as mm

warnings.filterwarnings("ignore")
FS = 30000.0
M = 2147483647.0


class Lehmer:
    def __init__(self, seed):
        self.x = float(seed)

    def u(self):
        self.x = (16807.0 * self.x) % M
        return self.x / M

    def z(self):                      # Irwin-Hall: 12 uniforms - 6 (mean 0, sd 1), summed left to right
        s = 0.0
        for _ in range(12):
            s = s + self.u()
        return s - 6.0


def make_case(seed, T):
    g = Lehmer(seed)
    n = int(round(T * FS))
    trains = []
    # u0: 4000 times, quiet 60-120 s when T >= 180, plus 40 doublets 0.2-1.4 ms after a spike
    t = [T * g.u() for _ in range(4000)]
    if T >= 180:
        t = [x for x in t if x < 60 or x > 120]
    d = []
    for _ in range(40):
        i = int(np.floor(g.u() * len(t)))
        d.append(t[i] + 0.0002 + 0.0012 * g.u())
    trains.append(t + d)
    trains.append([T * g.u() for _ in range(600)])                  # u1: 600 everywhere
    trains.append([min(30.0, T) * g.u() for _ in range(2700)])      # u2: the first 30 s only
    trains.append([T * g.u() for _ in range(250)])                  # u3: 250 everywhere
    lo = max(T - 15.0, 0.0)
    trains.append([lo + (T - lo) * g.u() for _ in range(300)])      # u4: the last 15 s
    units = []
    for k, tt in enumerate(trains):
        s = np.unique(np.minimum(np.floor(np.array(tt) * FS), n - 1)).astype(np.int64)
        amp = np.zeros(len(s)); y = np.zeros(len(s))
        for j in range(len(s)):
            if k == 0:
                a = 10.0 + 2.0 * g.z()
                while not a > 8.5:
                    a = 10.0 + 2.0 * g.z()
            elif k == 2:
                a = -(12.0 + 1.5 * g.z())
            else:
                a = 9.0 + 1.5 * g.z()
            amp[j] = a
        for j in range(len(s)):
            drift = 20.0 * (float(s[j]) / n) if k == 0 else 0.0
            y[j] = 100.0 + drift + 2.0 * g.z()
        units.append((s, amp, y))
    return units, n


def near_integer_smoothing(amp):
    a = -amp if np.median(amp) < 0 else amp
    if len(a) / 500 < 5:
        return False
    h = np.histogram(a, 500)[0].astype(float)
    p = gaussian_filter1d(h, 3, mode="nearest")
    r = np.round(p)
    return bool(np.any((np.abs(p - r) < 1e-9) & (r > 0)))


def run_case(name, T, seed):
    units, n = make_case(seed, T)
    for s, amp, y in units:
        if near_integer_smoothing(amp):
            raise SystemExit(f"{name}: a smoothed amplitude count lies within 1e-9 of an integer; pick another seed")
    sorting = sc.NumpySorting.from_unit_dict([{k: u[0] for k, u in enumerate(units)}], sampling_frequency=FS)
    rec = sc.NumpyRecording([np.zeros((n, 2), dtype="float32")], sampling_frequency=FS)
    rec.set_dummy_probe_from_locations(np.array([[0.0, 0.0], [0.0, 20.0]]))
    an = sc.create_sorting_analyzer(sorting, rec, format="memory", sparse=False)
    an.compute(["random_spikes", "templates", "noise_levels", "spike_amplitudes"])
    an.compute("spike_locations", method="center_of_mass")
    sv = sorting.to_spike_vector()
    amps = an.get_extension("spike_amplitudes").data["amplitudes"]
    locs = an.get_extension("spike_locations").data["spike_locations"]
    for ui in range(len(units)):
        idx = np.nonzero(sv["unit_index"] == ui)[0]
        assert np.array_equal(sv["sample_index"][idx], units[ui][0])
        amps[idx] = units[ui][1]
        locs["y"][idx] = units[ui][2]
        locs["x"][idx] = 0.0
    isi = mm.compute_isi_violations(an)
    pr = mm.compute_presence_ratios(an)
    ac = mm.compute_amplitude_cutoffs(an)
    dr = mm.compute_drift_metrics(an)
    f = lambda v: None if v is None or np.isnan(v) else float(v)
    out = []
    for ui, uid in enumerate(sorting.unit_ids):
        out.append(dict(unitId=int(uid), nSpikes=int(len(units[ui][0])),
                        firstSample=int(units[ui][0][0]), lastSample=int(units[ui][0][-1]),
                        sumAmplitude=float(np.sum(units[ui][1])), sumY=float(np.sum(units[ui][2])),
                        isiViolationsRatio=f(isi.isi_violations_ratio[uid]),
                        isiViolationsCount=int(isi.isi_violations_count[uid]),
                        presenceRatio=f(pr[uid]), amplitudeCutoff=f(ac[uid]),
                        driftPtp=f(dr.drift_ptp[uid]), driftStd=f(dr.drift_std[uid]), driftMad=f(dr.drift_mad[uid])))
    return dict(name=name, seed=seed, durationS=T, nSamples=n, units=out)


cases = [run_case("200 s", 200.0, 12345), run_case("100 s (one drift interval)", 100.0, 777),
         run_case("50 s (shorter than a presence bin)", 50.0, 4242)]
out = dict(generator="tools/golden/unit_quality_golden.py", spikeinterface=spikeinterface.__version__,
           numpy=np.__version__, scipy=scipy.__version__, fs=FS,
           parameters=dict(isiThresholdMs=1.5, minIsiMs=0, presenceBinS=60, amplitudeBins=500,
                           amplitudeSmoothing=3, amplitudeMinRatio=5, driftIntervalS=60,
                           driftMinSpikes=100, driftMinBins=2, driftMinValidFraction=0.5),
           cases=cases)
dest = Path(__file__).resolve().parents[2] / "pipeline" / "testdata" / "unit_quality_golden.json"
dest.write_text(json.dumps(out, indent=1) + "\n")
for c in cases:
    print(c["name"])
    for u in c["units"]:
        print("  u%d n=%d isi %s (%d) presence %s cutoff %s drift %s / %s / %s" % (u["unitId"], u["nSpikes"],
              u["isiViolationsRatio"], u["isiViolationsCount"], u["presenceRatio"], u["amplitudeCutoff"],
              u["driftPtp"], u["driftStd"], u["driftMad"]))
print(dest, dest.stat().st_size, "bytes")
