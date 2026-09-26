function result = runProbeTool(obj, varargin)
%runProbeTool  Invoke probe_tool.py (probeinterface front-door) via system().
%   RESULT = obj.runProbeTool(SUBCMD, ARG1, ARG2, ...) runs the checked-in
%   probe_tool.py in the Python/conda env configured on the Kilosort tab,
%   passing SUBCMD and the remaining tokens as command-line arguments. It
%   captures stdout, raises on a PROBE_TOOL_ERROR marker or non-zero exit, and
%   returns the JSON the script prints on its last output line, jsondecoded:
%
%     list-library            -> list of {manufacturer, probes}
%     get-library / generate  -> struct with fields out, n_contacts
%     get-contacts            -> struct with fields out, n_contacts (the
%                                file holds contact_ids, x, y, shank_ids)
%     describe                -> struct positions/shank_ids/device_channel_indices/...
%
%   probeinterface lives only in that env; the app itself stores and consumes
%   plain Kilosort4 probe .json, which is exactly what probe_tool.py writes.
%
%   Uses the same env-python-or-`conda run` dispatch as
%   EphysDataset.runKilosort (env python directly when no conda env is set;
%   conda is not required to be on PATH in that case). The command itself is
%   assembled by the static runProbeToolWith, which ChannelMapperApp also
%   uses when it runs on its own.
%
%   See also EphysPreprocessingApp.runProbeToolWith, EphysPreprocessingApp.onDesignProbe,
%   ProbeDesignerApp, ChannelMapperApp, EphysDataset.runKilosort.

if isempty(varargin)
    error('EphysPreprocessingApp:runProbeTool:NoSubcommand', ...
        'runProbeTool requires a subcommand (e.g. "list-library").');
end

pythonExe = strtrim(string(obj.PythonExeField.Value));
condaEnv  = strtrim(string(obj.CondaEnvField.Value));
if pythonExe == ""
    error('EphysPreprocessingApp:runProbeTool:NoPython', ...
        ['No Python executable configured. Set the Python exe on the ' ...
         'Kilosort tab (the same env used for sorting).']);
end

result = EphysPreprocessingApp.runProbeToolWith(pythonExe, condaEnv, varargin{:});
end
