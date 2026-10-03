"""Write one dataset as an NWB file from the staging folder EphysDataset.exportNWB fills.

Usage:  nwb_export.py <stage.json>

The staging folder holds
  stage.json   the structure and every text: session, subject, device,
               electrode groups, electrode and unit and trial text columns,
               the signals, events and what each array in stage.npz is
  stage.npz    every number, exactly as MATLAB holds it: rates, positions,
               spike times, trial times and columns, interval tables
  <SIG>.npy    one array per signal, shape (channels, samples), C order, so
               a block of samples of every channel is one run per channel

The file is built with pynwb, written as "~<name>.partial.nwb" next to the
target, checked with nwbinspector (which also runs pynwb's validation) and
then renamed into place. nwb_status.json in the staging folder says how it
went:
  {"state": "done", "file", "inspector": [messages], "versions": {...}}
  {"state": "error", "message", "traceback", "versions": {...}}
and the script prints NWB_EXPORT_DONE or NWB_EXPORT_ERROR as its last line.
Nothing is converted here: signals keep their dtype and are scaled by the
conversion given (microvolts x 1e-6 = volts), and times are written as
given (MATLAB has already put them on the clock of the signals).
"""
import json
import os
import sys
import traceback
import uuid
from datetime import datetime

import numpy as np


def versions():
    out = {"python": sys.version.split()[0], "numpy": np.__version__}
    for name in ("pynwb", "hdmf", "h5py", "nwbinspector"):
        try:
            out[name] = __import__(name).__version__
        except Exception:  # noqa: BLE001 - a version is only for the record
            out[name] = ""
    return out


def as_list(x):
    """A JSON list as a list: MATLAB's jsonencode writes a one-element struct array or text as the element alone."""
    if x is None:
        return []
    if isinstance(x, list):
        return x
    return [x]


def text(x):
    """None for an empty or missing text (pynwb takes None for "not given")."""
    if x is None:
        return None
    if isinstance(x, list):
        x = [str(v) for v in x if str(v) != ""]
        return x or None
    x = str(x)
    return x or None


def build(st, folder, arrays):
    from pynwb import NWBFile, TimeSeries
    from pynwb.ecephys import ElectricalSeries, FilteredEphys, LFP
    from pynwb.epoch import TimeIntervals
    from pynwb.file import Subject
    from hdmf.backends.hdf5.h5_utils import H5DataIO
    from hdmf.data_utils import DataChunkIterator

    s = st["session"]
    nwb = NWBFile(
        session_description=s["description"],
        identifier=s.get("identifier") or str(uuid.uuid4()),
        session_start_time=datetime.fromisoformat(s["start_time"]),
        session_id=text(s.get("session_id")),
        experimenter=text(s.get("experimenter")),
        experiment_description=text(s.get("experiment_description")),
        lab=text(s.get("lab")),
        institution=text(s.get("institution")),
        keywords=text(s.get("keywords")),
        notes=text(s.get("notes")),
        source_script=text(s.get("source_script")),
        source_script_file_name=text(s.get("source_script_file_name")),
    )
    sub = st.get("subject")
    if sub:
        nwb.subject = Subject(
            subject_id=text(sub.get("subject_id")),
            species=text(sub.get("species")),
            sex=text(sub.get("sex")),
            age=text(sub.get("age")),
            description=text(sub.get("description")),
            strain=text(sub.get("strain")),
            genotype=text(sub.get("genotype")),
        )

    # --- electrodes -------------------------------------------------------------------
    d = st["device"]
    device = nwb.create_device(name=d["name"], description=text(d.get("description")),
                               manufacturer=text(d.get("manufacturer")))
    groups = {}
    for g in as_list(st["electrode_groups"]):
        groups[g["name"]] = nwb.create_electrode_group(
            name=g["name"], description=g["description"], location=g["location"], device=device)
    el = st["electrodes"]
    n_el = int(el["count"])
    if n_el > 0:
        extra = as_list(el["extra_columns"])
        for c in extra:
            nwb.add_electrode_column(name=c["name"], description=c["description"])
        rel = el.get("positions", False)
        group_of = as_list(el["group"])
        location_of = as_list(el["location"])
        for i in range(n_el):
            row = dict(group=groups[group_of[i]], location=location_of[i])
            if rel:
                row["rel_x"] = float(arrays["electrodes_rel_x"][i])
                row["rel_y"] = float(arrays["electrodes_rel_y"][i])
            for c in extra:
                if c["kind"] == "text":
                    row[c["name"]] = as_list(c["values"])[i]
                elif c["kind"] == "bool":
                    row[c["name"]] = bool(arrays[c["key"]][i])
                else:
                    row[c["name"]] = arrays[c["key"]][i].item()
            nwb.add_electrode(**row)

    # --- signals ------------------------------------------------------------------------
    modules = {}
    for sig in as_list(st["signals"]):
        name = sig["name"]
        data = np.load(os.path.join(folder, sig["file"]), mmap_mode="r")   # (channels, samples)
        data = data.T                                                      # (samples, channels): a view
        n_t, n_c = data.shape
        block = max(1, min(n_t, int(sig.get("chunk_samples", 65536))))
        it = DataChunkIterator(data=data, buffer_size=block, iter_axis=0)
        io_data = H5DataIO(data=it, chunks=(min(n_t, 16384), n_c), compression="gzip", compression_opts=4)
        rate = float(arrays[sig["rate_key"]])
        conversion = float(arrays[sig["conversion_key"]])
        if sig["kind"] == "aux":
            ts = TimeSeries(name=name, data=io_data, unit="volts", rate=rate, starting_time=0.0,
                            conversion=conversion, description=sig["description"], comments=sig.get("comments", ""))
            nwb.add_acquisition(ts)
            continue
        rows = [int(v) for v in np.atleast_1d(arrays[sig["electrodes_key"]])]
        region = nwb.create_electrode_table_region(region=rows, description=name + ": the electrode of each column")
        es = ElectricalSeries(name=name, data=io_data, electrodes=region, rate=rate, starting_time=0.0,
                              conversion=conversion, filtering=text(sig.get("filtering")),
                              description=sig["description"], comments=sig.get("comments", ""))
        if "ecephys" not in modules:
            modules["ecephys"] = nwb.create_processing_module(
                name="ecephys", description="Signals derived from the wideband recording (ephys_analysis Signals step)")
        # the container joins the file before the series does, so the series' link to the
        # electrodes table is made inside one file
        box = LFP(name="LFP") if sig["kind"] == "lfp" else FilteredEphys(name=name)
        modules["ecephys"].add(box)
        box.add_electrical_series(es)

    # --- units --------------------------------------------------------------------------
    u = st.get("units")
    if u and int(u["count"]) > 0:
        import warnings
        from pynwb.misc import Units
        has_el = nwb.electrodes is not None and len(nwb.electrodes) > 0
        with warnings.catch_warnings():
            # the link is made before the table joins the file, which hdmf warns about; it is
            # fine once nwb.units is set
            warnings.filterwarnings("ignore", message="The linked table for DynamicTableRegion")
            nwb.units = Units(name="units", description=u["description"],
                              electrode_table=nwb.electrodes if has_el else None,
                              resolution=float(arrays["units_resolution"]) if "units_resolution" in arrays.files else None)
        ucols = as_list(u["columns"])
        for c in ucols:
            nwb.add_unit_column(name=c["name"], description=c["description"])
        times = arrays["units_spike_times"]
        ends = np.atleast_1d(arrays["units_spike_index"]).astype(np.int64)
        ids = np.atleast_1d(arrays["units_id"]).astype(np.int64)
        elec = np.atleast_1d(arrays["units_electrode"]).astype(np.int64)
        start = 0
        for k in range(int(u["count"])):
            row = dict(spike_times=times[start:ends[k]], id=int(ids[k]))
            if has_el:
                row["electrodes"] = [int(elec[k])] if elec[k] >= 0 else []   # every row needs the column
            for c in ucols:
                if c["kind"] == "text":
                    row[c["name"]] = as_list(c["values"])[k]
                elif c["kind"] == "bool":
                    row[c["name"]] = bool(np.atleast_1d(arrays[c["key"]])[k])
                else:
                    row[c["name"]] = float(np.atleast_1d(arrays[c["key"]])[k])
            nwb.add_unit(**row)
            start = int(ends[k])

    # --- trials -------------------------------------------------------------------------
    t = st.get("trials")
    if t and int(t["count"]) > 0:
        tcols = as_list(t["columns"])
        for c in tcols:
            nwb.add_trial_column(name=c["name"], description=c["description"])
        t0 = np.atleast_1d(arrays["trials_start_time"])
        t1 = np.atleast_1d(arrays["trials_stop_time"])
        for k in range(int(t["count"])):
            row = dict(start_time=float(t0[k]), stop_time=float(t1[k]))
            for c in tcols:
                if c["kind"] == "text":
                    row[c["name"]] = as_list(c["values"])[k]
                elif c["kind"] == "bool":
                    row[c["name"]] = bool(np.atleast_1d(arrays[c["key"]])[k])
                else:
                    row[c["name"]] = float(np.atleast_1d(arrays[c["key"]])[k])
            nwb.add_trial(**row)

    # --- digital lines and the periods erased -------------------------------------------
    for ev in as_list(st.get("events")):
        iv = np.atleast_2d(arrays[ev["key"]])
        if iv.size == 0:
            continue                        # a line without a pulse makes no table
        ti = TimeIntervals(name=ev["name"], description=ev["description"])
        for a, b in iv:
            ti.add_interval(start_time=float(a), stop_time=float(b))
        nwb.add_time_intervals(ti)
    if "invalid_times" in arrays.files:
        iv = np.atleast_2d(arrays["invalid_times"])
        if iv.size:
            nwb.add_invalid_times_column(name="reason", description="why the period is invalid")
            for a, b in iv:
                nwb.add_invalid_time_interval(start_time=float(a), stop_time=float(b), reason=st.get("invalid_reason", ""))
    return nwb


def inspect(path):
    from nwbinspector import inspect_nwbfile
    out = []
    for m in inspect_nwbfile(nwbfile_path=path):
        if m is None:
            continue
        out.append({
            "importance": m.importance.name,
            "severity": m.severity.name,
            "check": m.check_function_name,
            "message": m.message,
            "object_type": m.object_type,
            "object_name": m.object_name,
            "location": m.location or "",
        })
    return out


def main(stage_path):
    folder = os.path.dirname(os.path.abspath(stage_path))
    status_path = os.path.join(folder, "nwb_status.json")
    partial = None
    try:
        from pynwb import NWBHDF5IO
        with open(stage_path, encoding="utf-8") as f:
            st = json.load(f)
        if st.get("format") != "ephys_analysis-nwb-stage/1":
            raise ValueError("unknown staging format %r" % st.get("format"))
        target = st["target"]
        tdir, tname = os.path.split(target)
        partial = os.path.join(tdir, "~" + os.path.splitext(tname)[0] + ".partial.nwb")
        if os.path.exists(partial):
            os.remove(partial)
        with np.load(os.path.join(folder, "stage.npz"), allow_pickle=False) as arrays:
            nwb = build(st, folder, arrays)
            with NWBHDF5IO(partial, "w") as io:
                io.write(nwb)
        messages = inspect(partial) if st.get("inspect", True) else None
        os.replace(partial, target)
        status = {"state": "done", "file": target, "inspector": messages, "versions": versions()}
        with open(status_path, "w", encoding="utf-8") as f:
            json.dump(status, f, indent=1)
        print("NWB_EXPORT_DONE")
        return 0
    except Exception as e:  # noqa: BLE001 - every failure is reported to MATLAB
        if partial is not None and os.path.exists(partial):
            try:
                os.remove(partial)          # never leave half a file behind
            except OSError:
                pass
        status = {"state": "error", "message": "%s: %s" % (type(e).__name__, e),
                  "traceback": traceback.format_exc(), "versions": versions()}
        try:
            with open(status_path, "w", encoding="utf-8") as f:
                json.dump(status, f, indent=1)
        finally:
            print(traceback.format_exc(), file=sys.stderr)
            print("NWB_EXPORT_ERROR")
        return 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: nwb_export.py <stage.json>", file=sys.stderr)
        print("NWB_EXPORT_ERROR")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
