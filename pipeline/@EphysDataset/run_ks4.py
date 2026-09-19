import sys
import json
import os
import traceback

# run_kilosort() keyword arguments that may arrive in settings.json (e.g. from
# the KS4 extra-settings JSON); they are passed as arguments, not settings.
RUN_ARGS = ('do_CAR', 'invert_sign', 'save_extra_vars', 'save_preprocessed_copy',
            'bad_channels', 'clear_cache', 'torch_thread_lim')

# settings.json keys this driver consumes itself.
DRIVER_KEYS = ('probe', 'data_dtype')


def split_settings(cfg, recognized):
    """Split settings.json into KS4 settings, run_kilosort kwargs and dropped keys."""
    settings, run_args, dropped = {}, {}, []
    for k, v in cfg.items():
        if k in DRIVER_KEYS:
            continue
        if k in RUN_ARGS:
            run_args[k] = v
        elif k in recognized:
            settings[k] = v
        else:
            dropped.append(k)
    return settings, run_args, dropped


def main():
    if len(sys.argv) < 2:
        raise SystemExit('usage: run_ks4.py <settings.json>')
    with open(sys.argv[1], 'r') as f:
        cfg = json.load(f)

    status_path = os.path.join(cfg['results_dir'], 'ks4_status.json')

    try:
        import numpy as np
        from kilosort import run_kilosort
        from kilosort.io import load_probe
        from kilosort.run_kilosort import RECOGNIZED_SETTINGS

        settings, run_args, dropped = split_settings(cfg, RECOGNIZED_SETTINGS)
        if dropped:
            print('Dropped %d setting(s) Kilosort4 does not recognize: %s'
                  % (len(dropped), dropped), flush=True)
        out = run_kilosort(
            settings=settings,
            probe=load_probe(cfg['probe']),
            filename=cfg['filename'],
            data_dtype=cfg['data_dtype'],
            results_dir=cfg['results_dir'],
            **run_args,
        )
        n_units = int(np.unique(out[2]).size)   # (ops, st, clu, ...)
        with open(status_path, 'w') as f:
            json.dump({'state': 'done', 'num_units': n_units,
                       'dropped_params': dropped}, f)
        print('KILOSORT4_DONE units=%d' % n_units)
    except Exception as e:
        with open(status_path, 'w') as f:
            json.dump({'state': 'error', 'message': str(e),
                       'traceback': traceback.format_exc()}, f)
        print('KILOSORT4_ERROR')
        raise


if __name__ == '__main__':
    main()
