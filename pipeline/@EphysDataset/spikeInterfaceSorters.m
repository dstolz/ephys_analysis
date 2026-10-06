function [sorters, info] = spikeInterfaceSorters(opts)
%spikeInterfaceSorters  The SpikeInterface sorters installed in a Python.
%   [SORTERS, INFO] = EphysDataset.spikeInterfaceSorters(PythonExe=..., CondaEnv=...)
%   runs si_sorters.py (next to this file) with that Python through SYSTEM
%   and returns one element per installed sorter
%   (spikeinterface.sorters.installed_sorters), in name order:
%     name          "spykingcircus2", ...
%     version       the sorter's version ("" when SpikeInterface cannot say)
%     params        its default parameters as indented JSON text, as
%                   SpikeInterface gives them (nested objects and nulls kept)
%     descriptions  table Parameter / Default (JSON text) / Description,
%                   one row per top-level parameter
%   INFO has spikeinterface (its version), python and when (datetime).
%   "kilosort4" is listed when installed; the pipeline runs Kilosort4
%   itself (runKilosort), so the Sorting tab leaves it out.
%
%   Throws EphysDataset:spikeInterfaceSorters:Failed with Python's output
%   when the script does not run (no Python, no spikeinterface).
%
%   See also EphysDataset.runSpikeInterface.

arguments
    opts.PythonExe (1,1) string = ""
    opts.CondaEnv (1,1) string = ""
end
if opts.PythonExe == ""
    error('EphysDataset:spikeInterfaceSorters:NoPython', ...
        'No python executable given (the Sorting step''s Python exe).');
end
script = fullfile(fileparts(mfilename('fullpath')), 'si_sorters.py');
out = [tempname '.json'];
cleanup = onCleanup(@() deleteIfThere(out));
if opts.CondaEnv ~= ""
    cmd = sprintf('conda run -n %s "%s" "%s" "%s"', opts.CondaEnv, opts.PythonExe, script, out);
else
    cmd = sprintf('"%s" "%s" "%s"', opts.PythonExe, script, out);
end
[status, txt] = system(cmd);
if status ~= 0 || ~isfile(out)
    error('EphysDataset:spikeInterfaceSorters:Failed', ...
        'Could not list the SpikeInterface sorters with %s (status %d):\n%s', ...
        opts.PythonExe, status, strtrim(txt));
end
J = jsondecode(fileread(out));
info = struct('spikeinterface', string(J.spikeinterface), 'python', opts.PythonExe, ...
    'when', datetime('now'));
sorters = struct('name', {}, 'version', {}, 'params', {}, 'descriptions', {});
list = J.sorters;
if iscell(list); list = [list{:}]; end
for k = 1:numel(list)
    s = list(k);
    d = s.descriptions;
    if iscell(d); d = [d{:}]; end
    if isempty(d)
        T = table(strings(0, 1), strings(0, 1), strings(0, 1), ...
            'VariableNames', ["Parameter" "Default" "Description"]);
    else
        T = table(string({d.name}).', string({d.default}).', string({d.text}).', ...
            'VariableNames', ["Parameter" "Default" "Description"]);
    end
    sorters(end+1) = struct('name', string(s.name), 'version', string(s.version), ...
        'params', string(s.params), 'descriptions', T); %#ok<AGROW>
end
end


function deleteIfThere(f)
if isfile(f); delete(f); end
end
