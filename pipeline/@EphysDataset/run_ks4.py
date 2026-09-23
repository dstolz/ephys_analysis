import sys
import json
import os
import traceback

# run_kilosort() keyword arguments that may arrive in settings.json (e.g. from
# the KS4 extra-settings JSON); they are passed as arguments, not settings.
RUN_ARGS = ('do_CAR', 'invert_sign', 'save_extra_vars', 'save_preprocessed_copy',
            'bad_channels', 'clear_cache', 'torch_thread_lim')

# settings.json keys this driver consumes itself, or leaves alone: bin_scale
# (the .bin's units per uV) is for EphysDataset.readPhyUnits, not Kilosort4.
DRIVER_KEYS = ('probe', 'data_dtype', 'torch_device', 'bin_scale')


def device_arg(argv):
    """The value of --device <torch device> in ARGV, or None."""
    if '--device' in argv:
        i = argv.index('--device')
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


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
        raise SystemExit('usage: run_ks4.py <settings.json> [--device <torch device>]')
    with open(sys.argv[1], 'r') as f:
        cfg = json.load(f)

    status_path = os.path.join(cfg['results_dir'], 'ks4_status.json')

    try:
        import numpy as np
        import torch
        from kilosort import run_kilosort
        from kilosort.io import load_probe
        from kilosort.run_kilosort import RECOGNIZED_SETTINGS

        settings, run_args, dropped = split_settings(cfg, RECOGNIZED_SETTINGS)
        if dropped:
            print('Dropped %d setting(s) Kilosort4 does not recognize: %s'
                  % (len(dropped), dropped), flush=True)
        # --device (one GPU per run) wins over a torch_device in the settings.
        device = device_arg(sys.argv[2:]) or cfg.get('torch_device')
        if device and device != 'auto':
            run_args['device'] = torch.device(device)
            print('Kilosort4 on torch device %s' % device, flush=True)
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
