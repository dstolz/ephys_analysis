import sys
import os
import json
import traceback


def load_config(path):
    with open(path, 'r') as f:
        return json.load(f)


def log(msg):
    print(msg, flush=True)


def amplifier_stream_id(path):
    from spikeinterface.extractors import get_neo_streams
    names, ids = get_neo_streams('intan', path)
    for n, i in zip(names, ids):
        if 'amplifier' in str(n).lower():
            return i
    return ids[0]


def read_one(path):
    import spikeinterface.extractors as se
    return se.read_intan(path, stream_id=amplifier_stream_id(path))


def load_recording(cfg):
    """Build the SpikeInterface recording from the config's 'recording' spec.

    The spec is written by the dataset's EphysReader.siRecordingSpec():
      reader == 'intan'             -> read_intan over the *.rhd files / info.rhd
      reader == 'binary'            -> read_binary over a flat channel-major file
                                       (the universal ephys-recording/1 format)
      reader == 'openephys-binary'  -> read_binary per recording (continuous.dat)
      reader == 'openephys-legacy'  -> the .continuous record files
      reader == 'openephys-nwb'     -> the NWB ElectricalSeries (needs h5py)
    Open Ephys recordings are one segment per recording, concatenated, on the
    same row grid as the MATLAB reader. The channels are then renamed to the
    spec's channel_numbers (the hardware numbers a probe chanMap refers to).
    Configs without a 'recording' block are treated as Intan.
    """
    spec = cfg.get('recording') or {}
    reader = str(spec.get('reader', 'intan')).lower()
    if reader == 'binary':
        rec = load_binary_recording(spec)
    elif reader == 'openephys-binary':
        rec = load_openephys_binary(spec)
    elif reader == 'openephys-legacy':
        rec = load_openephys_legacy(spec)
    elif reader == 'openephys-nwb':
        rec = load_openephys_nwb(spec)
    elif reader == 'intan':
        rec = load_intan_recording(cfg, spec)
    else:
        raise ValueError('Unsupported recording reader: %s' % reader)
    return name_by_number(rec, spec)


def name_by_number(rec, spec):
    """Rename the channels to their hardware numbers (the probe chanMap values)."""
    numbers = spec.get('channel_numbers')
    if numbers is None:
        return rec
    numbers = [int(n) for n in numbers]
    if len(numbers) != rec.get_num_channels():
        raise ValueError('The recording spec lists %d channel numbers but the recording has %d channels.'
                         % (len(numbers), rec.get_num_channels()))
    if len(set(numbers)) != len(numbers):
        raise ValueError('The channel numbers are not unique: %s' % numbers)
    return rec.rename_channels(new_channel_ids=[str(n) for n in numbers])


def load_intan_recording(cfg, spec):
    import spikeinterface.full as si
    folder = cfg.get('folder') or spec.get('folder')
    fmt = cfg.get('recording_format', spec.get('recording_format', 'traditional'))
    if fmt in ('one-file-per-signal', 'one-file-per-channel'):
        return read_one(os.path.join(folder, 'info.rhd'))
    files = cfg.get('files') or spec.get('files') or []
    paths = [os.path.join(folder, f) for f in files]
    paths = [p for p in paths if os.path.isfile(p)]
    if not paths:
        raise FileNotFoundError('No .rhd files found in ' + folder)
    recs = [read_one(p) for p in paths]
    if len(recs) == 1:
        return recs[0]
    return si.concatenate_recordings(recs)


def load_binary_recording(spec):
    import numpy as np
    import spikeinterface.extractors as se
    import spikeinterface.preprocessing as spre
    name = str(spec['dtype']).lower()
    name = {'single': 'float32', 'double': 'float64'}.get(name, name)
    dtype = np.dtype(name)
    gain = float(spec.get('gain_to_uV', 1.0))
    offset = float(spec.get('offset', 0.0))
    rec = se.read_binary(spec['file'], sampling_frequency=float(spec['fs']),
                         dtype=dtype, num_channels=int(spec['n_chan']),
                         gain_to_uV=gain, offset_to_uV=-offset * gain,
                         time_axis=0, is_filtered=False)
    if dtype.kind == 'u':
        # Kilosort4 refuses unsigned dtypes. unsigned_to_signed subtracts
        # 2^(bits-1); keep microvolts = (raw - offset) * gain exact.
        rec = spre.unsigned_to_signed(rec)
        half = float(2 ** (8 * dtype.itemsize - 1))
        n = rec.get_num_channels()
        rec.set_property('gain_to_uV', np.full(n, gain))
        rec.set_property('offset_to_uV', np.full(n, (half - offset) * gain))
    log('Loaded binary recording %s (%s, %d ch, fs=%g)'
        % (spec['file'], dtype, rec.get_num_channels(), rec.get_sampling_frequency()))
    return rec


def _concatenate(recs):
    import spikeinterface.full as si
    return recs[0] if len(recs) == 1 else si.concatenate_recordings(recs)


def _headstage(rec, spec):
    """Keep the headstage channels (0-based stream positions) with their gains in uV."""
    import numpy as np
    idx = [int(i) for i in spec['channel_indices']]
    ids = [rec.channel_ids[i] for i in idx]
    rec = rec.select_channels(ids)
    rec.set_channel_gains(np.asarray(spec['gain_to_uV'], dtype=float))
    rec.set_channel_offsets(np.zeros(len(idx)))
    return rec


def load_openephys_binary(spec):
    """Open Ephys Binary: one continuous.dat (int16, all stream channels) per recording."""
    import spikeinterface.extractors as se
    n = int(spec['n_chan_stream'])
    recs = []
    for p in spec['parts']:
        r = se.read_binary(p['file'], sampling_frequency=float(spec['fs']), dtype='int16',
                           num_channels=n, time_axis=0, is_filtered=False)
        if r.get_num_samples() != int(p['n_samples']):
            r = r.frame_slice(0, int(p['n_samples']))
        recs.append(r)
    rec = _headstage(_concatenate(recs), spec)
    log('Loaded Open Ephys Binary recording (%d part(s), %d ch, fs=%g)'
        % (len(recs), rec.get_num_channels(), rec.get_sampling_frequency()))
    return rec


def load_openephys_legacy(spec):
    """Open Ephys format: the headstage .continuous files, one segment per recording."""
    import spikeinterface.full as si
    parts = [{'channel_files': list(p['channel_files']), 'first_record': int(p['first_record']),
              'n_records': int(p['n_records'])} for p in spec['parts']]
    rec = OpenEphysLegacyRecording(parts, float(spec['fs']), [float(g) for g in spec['gain_to_uV']])
    if rec.get_num_segments() > 1:
        rec = si.concatenate_recordings([rec.select_segments([i]) for i in range(rec.get_num_segments())])
    log('Loaded Open Ephys format recording (%d part(s), %d ch, fs=%g)'
        % (len(parts), rec.get_num_channels(), rec.get_sampling_frequency()))
    return rec


def load_openephys_nwb(spec):
    """Open Ephys NWB 2: the stream's ElectricalSeries, one segment per recording."""
    try:
        import h5py  # noqa: F401
    except ImportError:
        raise ImportError('Reading Open Ephys NWB files needs h5py in the sorting environment '
                          '(e.g. "conda install -n kilosort h5py"), or sort with the kilosort engine, '
                          'which reads the recording in MATLAB.')
    import spikeinterface.full as si
    parts = [{'file': p['file'], 'dataset': p['dataset'], 'row_start': int(p['row_start']),
              'n_samples': int(p['n_samples'])} for p in spec['parts']]
    rec = OpenEphysNwbRecording(parts, [int(i) for i in spec['channel_indices']], float(spec['fs']),
                                [float(g) for g in spec['gain_to_uV']])
    if rec.get_num_segments() > 1:
        rec = si.concatenate_recordings([rec.select_segments([i]) for i in range(rec.get_num_segments())])
    log('Loaded Open Ephys NWB recording (%d part(s), %d ch, fs=%g)'
        % (len(parts), rec.get_num_channels(), rec.get_sampling_frequency()))
    return rec


# --- Open Ephys format / NWB recordings ---------------------------------------
# Module-level classes: SpikeInterface dumps a recording (class path +
# _kwargs + the module's __version__) and rebuilds it, so they must be
# importable by name (__main__.<class>) and the module needs a version.
__version__ = '1.0.0'

import numpy as _np
from spikeinterface.core import BaseRecording as _BaseRecording
from spikeinterface.core import BaseRecordingSegment as _BaseRecordingSegment

_LEGACY_RECORD = _np.dtype([('ts', '<i8'), ('n', '<u2'), ('rec', '<u2'),
                            ('s', '>i2', (1024,)), ('m', 'u1', (10,))])


def _channel_list(channel_indices, n):
    if channel_indices is None:
        return list(range(n))
    if isinstance(channel_indices, slice):
        return list(range(n))[channel_indices]
    return [int(c) for c in channel_indices]


class OpenEphysLegacySegment(_BaseRecordingSegment):
    """One recording of .continuous files: records [first, first + n) of each channel file."""

    def __init__(self, files, first_record, n_records, fs):
        _BaseRecordingSegment.__init__(self, sampling_frequency=fs)
        self._maps = [_np.memmap(f, dtype=_LEGACY_RECORD, mode='r', offset=1024) for f in files]
        self._first = int(first_record)
        self._n = int(n_records)

    def get_num_samples(self):
        return self._n * 1024

    def get_traces(self, start_frame=None, end_frame=None, channel_indices=None):
        start = 0 if start_frame is None else int(start_frame)
        end = self.get_num_samples() if end_frame is None else int(end_frame)
        chans = _channel_list(channel_indices, len(self._maps))
        out = _np.zeros((max(end - start, 0), len(chans)), dtype='int16')
        if end <= start:
            return out
        r0 = self._first + start // 1024
        r1 = self._first + (end - 1) // 1024 + 1
        off = start % 1024
        for j, c in enumerate(chans):
            v = self._maps[c][r0:r1]['s'].reshape(-1)
            out[:, j] = v[off:off + (end - start)]
        return out


class OpenEphysLegacyRecording(_BaseRecording):
    """Open Ephys format headstage channels; one segment per recording."""

    def __init__(self, parts, fs, gains):
        n = len(parts[0]['channel_files'])
        _BaseRecording.__init__(self, sampling_frequency=float(fs),
                                channel_ids=[str(i) for i in range(n)], dtype='int16')
        for p in parts:
            self.add_recording_segment(OpenEphysLegacySegment(
                p['channel_files'], p['first_record'], p['n_records'], float(fs)))
        self.set_channel_gains(_np.asarray(gains, dtype=float))
        self.set_channel_offsets(_np.zeros(n))
        self._kwargs = {'parts': [dict(p) for p in parts], 'fs': float(fs), 'gains': [float(g) for g in gains]}


class OpenEphysNwbSegment(_BaseRecordingSegment):
    """One recording of an NWB ElectricalSeries: rows [row_start, row_start + n) (h5py)."""

    def __init__(self, file, dataset, row_start, n_samples, channel_indices, fs):
        _BaseRecordingSegment.__init__(self, sampling_frequency=fs)
        self._file, self._ds = file, dataset
        self._row0, self._n = int(row_start), int(n_samples)
        self._idx = _np.asarray(channel_indices, dtype=int)
        self._h5 = None

    def _data(self):
        if self._h5 is None:
            import h5py
            self._h5 = h5py.File(self._file, 'r')
        return self._h5[self._ds]

    def get_num_samples(self):
        return self._n

    def get_traces(self, start_frame=None, end_frame=None, channel_indices=None):
        start = 0 if start_frame is None else int(start_frame)
        end = self._n if end_frame is None else int(end_frame)
        cols = self._idx[_channel_list(channel_indices, len(self._idx))]
        if end <= start or cols.size == 0:
            return _np.zeros((max(end - start, 0), cols.size), dtype='int16')
        lo, hi = int(cols.min()), int(cols.max()) + 1
        block = self._data()[self._row0 + start:self._row0 + end, lo:hi]
        return _np.asarray(block[:, cols - lo], dtype='int16')


class OpenEphysNwbRecording(_BaseRecording):
    """Open Ephys NWB headstage channels; one segment per recording."""

    def __init__(self, parts, channel_indices, fs, gains):
        n = len(channel_indices)
        _BaseRecording.__init__(self, sampling_frequency=float(fs),
                                channel_ids=[str(i) for i in range(n)], dtype='int16')
        for p in parts:
            self.add_recording_segment(OpenEphysNwbSegment(
                p['file'], p['dataset'], p['row_start'], p['n_samples'], channel_indices, float(fs)))
        self.set_channel_gains(_np.asarray(gains, dtype=float))
        self.set_channel_offsets(_np.zeros(n))
        self._kwargs = {'parts': [dict(p) for p in parts], 'channel_indices': [int(i) for i in channel_indices],
                        'fs': float(fs), 'gains': [float(g) for g in gains]}


def build_probe(cfg, rec):
    import numpy as np
    from probeinterface import Probe
    d = load_config(cfg['probe'])
    xc = np.asarray(d['xc'], dtype=float).ravel()
    yc = np.asarray(d['yc'], dtype=float).ravel()
    n = xc.size
    chan_map = np.asarray(d.get('chanMap', np.arange(n))).astype(int).ravel()
    kc = d.get('kcoords')
    if kc is not None:
        kc = np.asarray(kc).astype(int).ravel()

    # Map each probe site's channel number to its position in THIS recording.
    # The channels are named by their hardware numbers (name_by_number), which
    # can have gaps when a channel was disabled at acquisition (e.g. 16
    # missing shifts every later channel down by one slot), so a site whose
    # number is absent is dropped rather than assumed to line up.
    pos_by_number = {}
    for pos, cid in enumerate(rec.channel_ids):
        try:
            pos_by_number[int(str(cid))] = pos
        except ValueError:
            pass

    keep = np.array([int(v) in pos_by_number for v in chan_map])
    missing = [str(v) for v, k in zip(chan_map, keep) if not k]
    if missing:
        log('Probe site(s) for channel number(s) %s are not present in this '
            'recording (disabled at acquisition?); dropping from the probe.'
            % ', '.join(missing))

    dev_idx = np.array([pos_by_number[int(v)] for v in chan_map[keep]])
    probe = Probe(ndim=2, si_units='um')
    probe.set_contacts(positions=np.column_stack([xc[keep], yc[keep]]),
        shapes='circle', shape_params={'radius': 6})
    probe.set_device_channel_indices(dev_idx)
    if kc is not None and kc.size == n:
        probe.set_shank_ids(kc[keep].astype(str))
    return probe


# Refuse to sort when artifact silencing would zero more than this share of
# the recording: Kilosort4 then finds no spikes and fails deep inside its
# template SVD with an unhelpful "Found array with 0 sample(s)".
MAX_SILENCED_FRACTION = 0.5


def silenced_samples(frames):
    """Samples covered by the union of (start, end) frame spans."""
    total, end = 0, -1
    for a, b in sorted(frames):
        a = max(a, end)
        if b > a:
            total += b - a
            end = b
    return total


def to_frames(periods_s, fs, n_samples):
    frames = []
    for p in periods_s:
        a = max(0, min(int(round(float(p[0]) * fs)), n_samples))
        b = max(0, min(int(round(float(p[1]) * fs)), n_samples))
        if b > a:
            frames.append((a, b))
    return frames


def _patch_silence_periods_dtype():
    # SilencedPeriodsRecording stores 'periods' as a structured np.array,
    # but run_sorter round-trips the whole recording through JSON
    # (dump -> tolist() -> json -> load) in-process before handing it to
    # Kilosort4, which collapses the structured array to a plain list of
    # lists. The constructor then rejects it. Patch the constructor here
    # so a reloaded plain list is rebuilt into the structured dtype.
    import numpy as np
    from spikeinterface.core.base import base_period_dtype
    from spikeinterface.preprocessing.silence_periods import SilencedPeriodsRecording as Cls
    if getattr(Cls, '_period_dtype_patched', False):
        return
    orig_init = Cls.__init__
    def patched_init(self, recording, periods=None, list_periods=None, mode='zeros', noise_levels=None, seed=None, **kwargs):
        if periods is not None and not isinstance(periods, np.ndarray):
            periods = np.array([tuple(row) for row in periods], dtype=base_period_dtype)
        orig_init(self, recording, periods=periods, list_periods=list_periods, mode=mode, noise_levels=noise_levels, seed=seed, **kwargs)
    Cls.__init__ = patched_init
    Cls._period_dtype_patched = True


def build_pipeline(cfg):
    import numpy as np
    import spikeinterface.preprocessing as spre
    rec = load_recording(cfg)
    log('Loaded recording: %d channels, %d samples, fs=%g, dtype=%s'
        % (rec.get_num_channels(), rec.get_num_samples(), rec.get_sampling_frequency(), rec.get_dtype()))

    # Intan amplifier data is stored as unsigned (offset-binary uint16);
    # Kilosort4 refuses unsigned dtypes, so always convert to signed.
    if rec.get_dtype().kind == 'u':
        rec = spre.unsigned_to_signed(rec)
        log('converted unsigned dtype to signed (%s)' % rec.get_dtype())

    # KS4 tmin/tmax are not accepted by the SI wrapper; honour them here by
    # cropping the recording (pop so they are not later flagged as dropped).
    ks = cfg.get('ks4', {}) or {}
    fs = rec.get_sampling_frequency()
    tmin = float(ks.pop('tmin', 0) or 0)
    tmax = ks.pop('tmax', None)
    if tmin > 0 or tmax is not None:
        end = int(round(float(tmax) * fs)) if (tmax is not None and np.isfinite(float(tmax))) else None
        rec = rec.frame_slice(start_frame=int(round(tmin * fs)), end_frame=end)
        log('cropped to tmin=%g tmax=%s (%d samples)' % (tmin, tmax, rec.get_num_samples()))

    orig_ids = list(rec.channel_ids)
    excl = cfg.get('exclude_channels', []) or []
    manual_bad = [orig_ids[i] for i in [int(x) for x in excl] if 0 <= i < len(orig_ids)]

    rec = rec.set_probe(build_probe(cfg, rec))
    pp = cfg.get('preprocessing', {})

    filt = pp.get('filter', {})
    if filt.get('enabled'):
        rec = spre.bandpass_filter(rec, freq_min=float(filt.get('freq_min', 300)),
                                   freq_max=float(filt.get('freq_max', 6000)))
        log('bandpass_filter %g-%g Hz' % (filt.get('freq_min', 300), filt.get('freq_max', 6000)))

    dbc = pp.get('detect_bad_channels', {})
    bad = list(manual_bad)
    if dbc.get('enabled'):
        det_rec = rec if filt.get('enabled') else spre.highpass_filter(rec, freq_min=300.0)
        auto_bad, labels = spre.detect_bad_channels(det_rec, method=dbc.get('method', 'coherence+psd'))
        log('detect_bad_channels flagged %d channel(s): %s'
            % (len(auto_bad), list(map(str, auto_bad))))
        for b in auto_bad:
            if b not in bad:
                bad.append(b)
    bad = [b for b in bad if b in list(rec.channel_ids)]
    if bad and len(bad) >= rec.get_num_channels():
        log('WARNING: bad-channel detection flagged all %d channel(s); skipping removal'
            % rec.get_num_channels())
        bad = []
    if bad:
        if dbc.get('action', 'remove') == 'interpolate':
            rec = spre.interpolate_bad_channels(rec, bad)
            log('interpolated %d bad channel(s)' % len(bad))
        else:
            rec = rec.remove_channels(bad)
            log('removed %d bad channel(s); %d remain' % (len(bad), rec.get_num_channels()))

    cmr = pp.get('common_reference', {})
    if cmr.get('enabled'):
        rec = spre.common_reference(rec, operator=cmr.get('operator', 'median'), reference='global')
        log('common_reference (%s)' % cmr.get('operator', 'median'))

    sil = pp.get('silence_periods', {})
    if sil.get('enabled'):
        periods = [[float(a) - tmin, float(b) - tmin] for (a, b) in (sil.get('periods_s', []) or [])]
        n_samples = rec.get_num_samples()
        frames = to_frames(periods, fs, n_samples)
        if frames:
            covered = silenced_samples(frames)
            share = covered / float(n_samples)
            log('artifact periods cover %.4g of %.4g s (%.0f%%)'
                % (covered / fs, n_samples / fs, 100 * share))
            if share > MAX_SILENCED_FRACTION:
                raise ValueError(
                    'Artifact silencing would zero %.0f%% of the recording '
                    '(%d period(s), %.4g of %.4g s; limit %.0f%%). Kilosort4 '
                    'would find no spikes. Check the artifact detector settings '
                    'or turn off artifact silencing for this dataset.'
                    % (100 * share, len(frames), covered / fs, n_samples / fs,
                       100 * MAX_SILENCED_FRACTION))
            _patch_silence_periods_dtype()
            try:
                periods = np.array([(0, a, b) for (a, b) in frames],
                                   dtype=[('segment_index', 'int64'),
                                          ('start_sample_index', 'int64'),
                                          ('end_sample_index', 'int64')])
                rec = spre.silence_periods(rec, periods)
            except (ValueError, TypeError):
                rec = spre.silence_periods(rec, [frames])   # older list-per-segment API
            log('silenced %d artifact period(s)' % len(frames))

    return rec, bad


def device_arg(argv):
    """The value of --device <torch device> in ARGV, or None."""
    if '--device' in argv:
        i = argv.index('--device')
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


def ks4_params(cfg, device=None):
    import spikeinterface.sorters as ss
    requested = dict(cfg.get('ks4', {}) or {})
    if device:   # --device (one GPU per run) wins over a torch_device in ks4
        requested['torch_device'] = device
        log('Kilosort4 on torch device %s' % device)
    try:
        accepted = ss.get_default_sorter_params('kilosort4')
    except Exception:
        accepted = {}
    params, dropped = {}, []
    for k, v in requested.items():
        if (not accepted) or (k in accepted):
            params[k] = v
        else:
            dropped.append(k)
    if dropped:
        log('Dropped %d KS4 setting(s) not accepted by the SI wrapper: %s' % (len(dropped), dropped))
    return params, dropped


def main():
    if len(sys.argv) < 2:
        raise SystemExit('usage: run_si_ks4.py <si_config.json> [--check] [--device <torch device>]')
    cfg = load_config(sys.argv[1])
    check = '--check' in sys.argv[1:]
    device = device_arg(sys.argv[2:])
    status_path = cfg['status_path']
    if check:
        rec, bad = build_pipeline(cfg)
        params, dropped = ks4_params(cfg, device)
        log('CHECK OK: %d channel(s) feed Kilosort4 (probe %s); KS4 params %d ok, %d dropped'
            % (rec.get_num_channels(), os.path.basename(cfg['probe']), len(params), len(dropped)))
        return
    try:
        import spikeinterface.full as si
        rec, bad = build_pipeline(cfg)
        params, dropped = ks4_params(cfg, device)
        results_dir = cfg['results_dir']
        log('Running Kilosort4 via SpikeInterface -> %s' % results_dir)
        # Keep the preprocessed recording.dat that KS4 writes during sorting
        # (SI deletes it by default) so phy can display raw traces/waveforms.
        params.setdefault('delete_recording_dat', False)
        sorting = si.run_sorter('kilosort4', rec, folder=results_dir,
                                remove_existing_folder=True, verbose=True, **params)
        n_units = int(len(sorting.unit_ids))
        with open(status_path, 'w') as f:
            json.dump({'state': 'done', 'num_units': n_units,
                       'bad_channels': list(map(str, bad)), 'dropped_params': dropped}, f)
        log('KILOSORT4_DONE units=%d' % n_units)
    except Exception as e:
        with open(status_path, 'w') as f:
            json.dump({'state': 'error', 'message': str(e),
                       'traceback': traceback.format_exc()}, f)
        log('KILOSORT4_ERROR')
        raise


if __name__ == '__main__':
    main()
