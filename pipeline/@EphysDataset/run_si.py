"""Sort the pipeline's .bin with a SpikeInterface sorter and write phy files.

usage: run_si.py <settings.json> [--device <torch device>]

EphysDataset.runSpikeInterface writes settings.json and the sorter's
parameters (si_params.json, as edited on the Sorting tab) into the run
folder, then starts this driver. It

  1. reads the .bin Kilosort4 would sort (artifact periods erased, the
     common reference applied once) with the probe .json attached,
  2. runs spikeinterface.run_sorter on it in <run folder>/si_work, keeping
     the sorter's own common reference out when the .bin already carries
     one (the sorters' do_CAR / car setting, or the common_reference call
     of SpikeInterface's internal sorters),
  3. computes templates, amplitudes, spike positions and the quality metrics
     on a 300 Hz high-pass of the .bin (a SortingAnalyzer in memory),
  4. labels each unit "good" or "mua" by the good-unit criteria in
     settings.json (unitQualityPass: the same thresholds and rules), and
  5. writes the phy files straight into the run folder, in the layout
     Kilosort4 leaves: channel_map.npy holds .bin rows, params.py names the
     .bin, templates.npy is dense and not whitened (whitening_mat_inv.npy is
     the identity), cluster_SILabel.tsv holds the labels and cluster_group.tsv
     a copy of it that keeps the "SILabel" header (phy's own copy says
     "group").

si_status.json gets state "done" or "error" when it finishes, as
ks4_status.json does for run_ks4.py.
"""
import sys
import json
import os
import shutil
import traceback
import warnings

# The files this driver leaves in the run folder: an earlier sort's are
# deleted first, so a failed run never leaves the old sort looking new.
PHY_FILES = ('params.py', 'spike_times.npy', 'spike_templates.npy', 'spike_clusters.npy',
             'templates.npy', 'template_ind.npy', 'similar_templates.npy',
             'channel_map.npy', 'channel_map_si.npy', 'channel_positions.npy',
             'channel_groups.npy', 'channel_shanks.npy', 'amplitudes.npy',
             'pc_features.npy', 'pc_feature_ind.npy', 'whitening_mat.npy',
             'whitening_mat_inv.npy', 'spike_positions.npy', 'cluster_group.tsv',
             'cluster_SILabel.tsv', 'cluster_si_unit_ids.tsv', 'cluster_channel_group.tsv')

# Good-unit criteria (unitQualityCriteria) -> SpikeInterface metric, rule.
CRITERIA = (('isiViolationsRatioMax', 'isi_violations_ratio', 'max'),
            ('presenceRatioMin', 'presence_ratio', 'min'),
            ('amplitudeCutoffMax', 'amplitude_cutoff', 'max'),
            ('snrMin', 'snr', 'min'),
            ('driftPtpMax', 'drift_ptp', 'max'),
            ('firingRateMin', 'firing_rate', 'min'))

# Template window (ms) of the analyzer: templates.npy and the SNR.
MS_BEFORE, MS_AFTER = 1.0, 2.0


def device_arg(argv):
    """The value of --device <torch device> in ARGV, or None."""
    if '--device' in argv:
        i = argv.index('--device')
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


def merge_params(defaults, given):
    """GIVEN over the sorter's DEFAULTS; nested dicts merge key by key.

    Returns the parameters and the top-level keys of GIVEN the sorter does
    not have (dropped: run_sorter refuses unknown parameters).
    """
    out, dropped = dict(defaults), []
    for k, v in given.items():
        if k not in defaults:
            dropped.append(k)
        elif isinstance(v, dict) and isinstance(defaults[k], dict):
            out[k] = merge_params_nested(defaults[k], v)
        else:
            out[k] = v
    return out, dropped


def merge_params_nested(defaults, given):
    """GIVEN over DEFAULTS at any depth; nested keys are all kept."""
    out = dict(defaults)
    for k, v in given.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = merge_params_nested(out[k], v)
        else:
            out[k] = v
    return out


def read_probe(path):
    """A Kilosort4 probe .json as a probeinterface Probe, and {chanMap: kcoords}."""
    import numpy as np
    from probeinterface import Probe
    with open(path, 'r') as f:
        p = json.load(f)
    cm = np.atleast_1d(np.asarray(p['chanMap'])).astype(int)
    x = np.atleast_1d(np.asarray(p['xc'], dtype=float))
    y = np.atleast_1d(np.asarray(p['yc'], dtype=float))
    k = np.atleast_1d(np.asarray(p.get('kcoords', np.zeros(cm.size)), dtype=float)).astype(int)
    probe = Probe(ndim=2, si_units='um')
    probe.set_contacts(positions=np.column_stack([x, y]), shapes='circle',
                       shape_params={'radius': 6})
    probe.set_device_channel_indices(cm)
    probe.set_shank_ids([str(s) for s in k])
    return probe, {int(c): int(s) for c, s in zip(cm, k)}


def keep_reference_out(sorter, params, mode):
    """Keep the sorter from adding a common reference to a referenced .bin.

    The .bin carries the pipeline's common reference (MODE "car" / "cmr"),
    so a second one would change the data, as Kilosort4's do_CAR would
    (runKilosort turns that off). Sorters with a do_CAR / car setting get it
    off; SpikeInterface's internal sorters (spykingcircus2, tridesclous2,
    lupin, ...) call common_reference themselves on 32 channels or more,
    with no setting for it, so that call is made to leave the recording as
    it is. Returns what was done, for the log.
    """
    import importlib
    import spikeinterface.sorters as ss
    done = []
    for key in ('do_CAR', 'car'):
        if key in params and params[key]:
            params[key] = False
            done.append('%s = False' % key)
    module = importlib.import_module(ss.sorter_dict[sorter].__module__)
    if callable(getattr(module, 'common_reference', None)):
        module.common_reference = lambda recording, *args, **kwargs: recording
        done.append('its common_reference skipped')
    if done:
        print('The .bin carries the common %s reference: %s (%s), so it is referenced once.'
              % (mode.upper(), sorter, ', '.join(done)), flush=True)
    else:
        print('The .bin carries the common %s reference; %s has no common reference of its own '
              'that this driver knows of.' % (mode.upper(), sorter), flush=True)


def unit_labels(metrics, criteria):
    """"good" / "mua" per unit (row of METRICS) by CRITERIA, as unitQualityPass judges.

    A threshold that is None / NaN is not applied. A NaN metric (could not be
    computed) passes, or fails when criteria["unknown"] is "fail".
    """
    import numpy as np
    n = len(metrics)
    good = np.ones(n, dtype=bool)
    unknown_fails = str(criteria.get('unknown', 'pass')) == 'fail'
    for field, metric, rule in CRITERIA:
        lim = criteria.get(field)
        if lim is None or (isinstance(lim, float) and np.isnan(lim)):
            continue
        if isinstance(lim, str):
            continue                         # "NaN" written as text: not applied
        lim = float(lim)
        if metric in metrics:
            v = metrics[metric].to_numpy(dtype=float)
        else:
            v = np.full(n, np.nan)
        bad = (v >= lim) if rule == 'max' else (v <= lim)
        good &= ~bad
        if unknown_fails:
            good &= ~np.isnan(v)
    return ['good' if g else 'mua' for g in good]


def write_labels(folder, labels):
    """cluster_SILabel.tsv, and the copy as cluster_group.tsv phy shows."""
    lines = ['cluster_id\tSILabel'] + ['%d\t%s' % (i, s) for i, s in enumerate(labels)]
    text = '\n'.join(lines) + '\n'
    for name in ('cluster_SILabel.tsv', 'cluster_group.tsv'):
        with open(os.path.join(folder, name), 'w', newline='\n') as f:
            f.write(text)


def write_params_py(folder, cfg):
    """params.py naming the .bin itself, all its channels (as Kilosort4's does)."""
    with open(os.path.join(folder, 'params.py'), 'w') as f:
        f.write("dat_path = r'%s'\n" % os.path.normpath(cfg['filename']))
        f.write('n_channels_dat = %d\n' % int(cfg['n_chan_bin']))
        f.write("dtype = '%s'\n" % cfg['data_dtype'])
        f.write('offset = 0\n')
        f.write('sample_rate = %r\n' % float(cfg['fs']))
        f.write('hp_filtered = False\n')


def export(analyzer, recording, shanks, results_dir, cfg, job_kwargs):
    """Write the phy files of ANALYZER into RESULTS_DIR (see the module help)."""
    import numpy as np
    from spikeinterface.exporters import export_to_phy
    tmp = os.path.join(results_dir, 'si_export')
    # The PCs phy shows, fitted one channel after another: SpikeInterface
    # fits them in a process pool whenever n_jobs > 1, far slower here.
    analyzer.compute('principal_components', n_components=5, mode='by_channel_local', n_jobs=1)
    export_to_phy(analyzer, tmp, compute_pc_features=True, compute_amplitudes=True,
                  copy_binary=False, remove_if_exists=True, add_quality_metrics=False,
                  add_template_metrics=False, verbose=False, **job_kwargs)

    # Dense templates (zero off each unit's channels), not whitened.
    templates = analyzer.get_extension('templates').get_templates(operator='average')
    np.save(os.path.join(tmp, 'templates.npy'), templates.astype(np.float32))
    ti = os.path.join(tmp, 'template_ind.npy')
    if os.path.isfile(ti):
        os.remove(ti)
    nc = templates.shape[2]
    np.save(os.path.join(tmp, 'whitening_mat.npy'), np.eye(nc, dtype=np.float32))
    np.save(os.path.join(tmp, 'whitening_mat_inv.npy'), np.eye(nc, dtype=np.float32))

    # The sorted channels as .bin rows (0-based), and their shanks (kcoords).
    rows = np.array([int(c) for c in recording.channel_ids], dtype=np.int32)
    np.save(os.path.join(tmp, 'channel_map.npy'), rows)
    np.save(os.path.join(tmp, 'channel_shanks.npy'),
            np.array([shanks.get(int(r), 0) for r in rows], dtype=np.int32))

    # Amplitudes as magnitudes (SpikeInterface's are signed: negative for a
    # trough), and the spike positions Kilosort4 also writes.
    amp = np.load(os.path.join(tmp, 'amplitudes.npy'))
    np.save(os.path.join(tmp, 'amplitudes.npy'), np.abs(amp).astype(np.float32))
    loc = analyzer.get_extension('spike_locations').get_data()
    np.save(os.path.join(tmp, 'spike_positions.npy'),
            np.column_stack([loc['x'], loc['y']]).astype(np.float32))

    write_params_py(tmp, cfg)
    for name in os.listdir(tmp):
        shutil.move(os.path.join(tmp, name), os.path.join(results_dir, name))
    shutil.rmtree(tmp, ignore_errors=True)


def update_settings(path, **fields):
    """Add FIELDS to the run's settings.json (what readPhyUnits reads there)."""
    with open(path, 'r') as f:
        s = json.load(f)
    s.update(fields)
    with open(path, 'w') as f:
        json.dump(s, f, indent=2)


def main():
    if len(sys.argv) < 2:
        raise SystemExit('usage: run_si.py <settings.json> [--device <torch device>]')
    settings_path = sys.argv[1]
    with open(settings_path, 'r') as f:
        cfg = json.load(f)
    results_dir = cfg['results_dir']
    status_path = os.path.join(results_dir, 'si_status.json')
    work = os.path.join(results_dir, 'si_work')

    try:
        import numpy as np
        import spikeinterface as si
        import spikeinterface.sorters as ss
        import spikeinterface.preprocessing as spre
        from spikeinterface.core import NumpySorting, create_sorting_analyzer
        from spikeinterface.extractors import read_binary

        sorter = cfg['sorter']
        print('SpikeInterface %s, sorter %s %s' % (si.__version__, sorter,
              ss.sorter_dict[sorter].get_sorter_version()), flush=True)
        given = {}
        if cfg.get('sorter_params'):
            with open(os.path.join(os.path.dirname(settings_path), cfg['sorter_params']), 'r') as f:
                text = f.read().strip()
            if text:
                given = json.loads(text)
        params, dropped = merge_params(ss.get_default_sorter_params(sorter), given)
        if dropped:
            print('Dropped %d parameter(s) %s does not have: %s' % (len(dropped), sorter, dropped),
                  flush=True)
        device = device_arg(sys.argv[2:])
        if device:
            print('Device %s: not used by SpikeInterface sorters here.' % device, flush=True)
        if cfg.get('reference', 'none') in ('car', 'cmr'):
            keep_reference_out(sorter, params, cfg['reference'])

        # Threads, not processes: on Windows every process pool imports
        # SpikeInterface again in each worker, which took most of the time.
        job_kwargs = dict(n_jobs=int(cfg.get('n_jobs', 1)), chunk_duration='1s', progress_bar=True,
                          pool_engine='thread')
        si.set_global_job_kwargs(**job_kwargs)

        for name in PHY_FILES:
            p = os.path.join(results_dir, name)
            if os.path.isfile(p):
                os.remove(p)

        probe, shanks = read_probe(cfg['probe'])
        recording = read_binary(file_paths=[cfg['filename']], sampling_frequency=float(cfg['fs']),
                                dtype=cfg['data_dtype'], num_channels=int(cfg['n_chan_bin']))
        recording = recording.set_probe(probe, group_mode='by_shank')
        print('Sorting %d of %d .bin channel(s), %.1f s' % (recording.get_num_channels(),
              int(cfg['n_chan_bin']), recording.get_total_duration()), flush=True)

        # run_sorter hands the sorter the recording as a JSON file, which keeps
        # the contact positions and channel groups but not the probe itself.
        # SpikeInterface's own sorters (lupin, spykingcircus2, ...) then build
        # a probe from those positions, all they use of it, and warn each time.
        warnings.filterwarnings('ignore', message='There is no Probe attached to this recording')
        sorting = ss.run_sorter(sorter, recording, folder=work, remove_existing_folder=True,
                                verbose=True, raise_error=True, **params)
        sorting = NumpySorting.from_sorting(sorting).remove_empty_units()
        if sorting.get_num_units() == 0:
            raise RuntimeError('%s found no units.' % sorter)
        print('%s found %d unit(s); computing templates, amplitudes, positions and quality metrics'
              % (sorter, sorting.get_num_units()), flush=True)

        # Templates etc. on a high-pass of the .bin, in its own units (no
        # gain: readPhyUnits gives them in uV with bin_scale, as for Kilosort4).
        filtered = spre.highpass_filter(recording, freq_min=300.0)
        analyzer = create_sorting_analyzer(sorting, filtered, format='memory', sparse=True,
                                           return_in_uV=False)
        analyzer.compute('random_spikes', max_spikes_per_unit=500, seed=0)
        analyzer.compute('waveforms', ms_before=MS_BEFORE, ms_after=MS_AFTER)
        analyzer.compute(['templates', 'noise_levels'])
        analyzer.compute('spike_amplitudes')
        analyzer.compute('spike_locations', method='center_of_mass')
        analyzer.compute('quality_metrics', metric_names=['firing_rate', 'presence_ratio', 'snr',
                         'isi_violation', 'amplitude_cutoff', 'drift'], skip_pc_metrics=True)
        metrics = analyzer.get_extension('quality_metrics').get_data()
        labels = unit_labels(metrics.loc[list(sorting.unit_ids)], cfg.get('quality', {}))

        export(analyzer, recording, shanks, results_dir, cfg, job_kwargs)
        write_labels(results_dir, labels)
        update_settings(settings_path,
                        nt0min=int(analyzer.get_extension('templates').nbefore))
        shutil.rmtree(work, ignore_errors=True)

        n_units, n_good = len(labels), labels.count('good')
        with open(status_path, 'w') as f:
            json.dump({'state': 'done', 'num_units': n_units, 'num_good': n_good,
                       'sorter': sorter, 'dropped_params': dropped}, f)
        print('SPIKEINTERFACE_DONE units=%d good=%d' % (n_units, n_good))
    except Exception as e:
        with open(status_path, 'w') as f:
            json.dump({'state': 'error', 'message': str(e),
                       'traceback': traceback.format_exc()}, f)
        print('SPIKEINTERFACE_ERROR')
        raise


if __name__ == '__main__':
    main()
