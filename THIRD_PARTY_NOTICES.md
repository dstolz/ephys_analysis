# Third-party code

[LICENSE](LICENSE) covers the code written for this repository. The files
below come from elsewhere and keep their own terms. Each entry says only
what the files themselves state.

| Path | Origin | Terms |
| --- | --- | --- |
| [`toolboxes/chronux`](toolboxes/chronux) | [Chronux](http://chronux.org) 2.10, bundled for analyzing the Chronux export | GNU GPL version 2 ([`chronux_addons/License.txt`](toolboxes/chronux/chronux_addons/License.txt)). That file notes that the license does not necessarily apply to the Matlab-R link, R-D(Com) or `dataio` software included with the release. No code in `pipeline/` or `analysis/` calls Chronux; the pipeline only writes files in the shapes Chronux takes. |
| [`pipeline/read_Intan_RHD2000_file_modified.m`](pipeline/read_Intan_RHD2000_file_modified.m) | Intan Technologies' `read_Intan_RHD2000_file` (version 3.0, 8 February 2021), modified for `IntanReader` (the header lists the changes) | The file states no license. Intan distributes its reader from [intantech.com](https://intantech.com/downloads.html?tabSelect=Software). |
| [`vendor/compute/parfor_progress.m`](vendor/compute/parfor_progress.m) | `parfor_progress` by Jeremy Scheff, copied from the author's `helper_fnc` | The file names its author and states no license. |
| [`vendor/tools/Manifest.m`](vendor/tools/Manifest.m), [`vendor/function_helpers/ternary.m`](vendor/function_helpers/ternary.m) | the author's `helper_fnc` repository, commit `61611a9` ([vendor/README.md](vendor/README.md)) | Same author as this repository. |

Python packages the drivers import (Kilosort4, probeinterface, PyTorch, phy,
pynwb, nwbinspector) are installed separately and are not part of this repository; see
[pipeline/INSTALL.md](pipeline/INSTALL.md).
