"""List the SpikeInterface sorters installed in this Python, as JSON.

usage: si_sorters.py <output.json>

EphysDataset.spikeInterfaceSorters runs this to fill the Sorting tab's
sorter list. The file holds
  {"spikeinterface": "<version>",
   "sorters": [{"name": ..., "version": ...,
                "params": "<the default parameters as indented JSON text>",
                "descriptions": [{"name": <parameter>, "default": "<JSON>",
                                  "text": <description>}, ...]}, ...]}
The defaults travel as text, so the null / nested values SpikeInterface
uses reach the Sorting tab (and run_si.py) exactly as they are.
"""
import sys
import json


def to_json(v):
    """V as JSON-compatible data (numpy scalars and arrays, tuples)."""
    try:
        import numpy as np
        if isinstance(v, np.generic):
            return v.item()
        if isinstance(v, np.ndarray):
            return v.tolist()
    except ImportError:
        pass
    if isinstance(v, dict):
        return {str(k): to_json(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [to_json(x) for x in v]
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    return str(v)


def main():
    if len(sys.argv) < 2:
        raise SystemExit('usage: si_sorters.py <output.json>')
    import spikeinterface as si
    import spikeinterface.sorters as ss
    out = {'spikeinterface': si.__version__, 'sorters': []}
    for name in sorted(ss.installed_sorters()):
        try:
            params = to_json(ss.get_default_sorter_params(name))
            try:
                desc = ss.get_sorter_params_description(name) or {}
            except Exception:
                desc = {}
            try:
                version = str(ss.sorter_dict[name].get_sorter_version())
            except Exception:
                version = ''
            out['sorters'].append({
                'name': name,
                'version': version,
                'params': json.dumps(params, indent=2),
                'descriptions': [{'name': k, 'default': json.dumps(params[k]),
                                  'text': str(desc.get(k, ''))} for k in params],
            })
        except Exception as e:
            print('skipped %s: %s' % (name, e), file=sys.stderr)
    with open(sys.argv[1], 'w') as f:
        json.dump(out, f)
    print('SI_SORTERS %d' % len(out['sorters']))


if __name__ == '__main__':
    main()
