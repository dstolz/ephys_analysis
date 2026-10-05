function result = runProbeToolWith(pythonExe, condaEnv, varargin)
%runProbeToolWith  Run probe_tool.py with a given Python (and conda env) via system().
%   RESULT = EphysPreprocessingApp.runProbeToolWith(PYTHONEXE, CONDAENV,
%   SUBCMD, ARG1, ...) runs the checked-in probe_tool.py with PYTHONEXE
%   (through `conda run -n CONDAENV` when CONDAENV is not ""), passing
%   SUBCMD and the remaining tokens as command-line arguments. It captures
%   stdout, raises on a PROBE_TOOL_ERROR marker or a non-zero exit, and
%   returns the JSON the script prints on its last output line, jsondecoded
%   (see runProbeTool for the subcommands).
%
%   runProbeTool calls this with the Kilosort tab's Python and conda env;
%   ChannelMapperApp, opened on its own, with the Python the app last used.
%
%   See also EphysPreprocessingApp.runProbeTool, ChannelMapperApp.runProbeTool.

if isempty(varargin)
    error('EphysPreprocessingApp:runProbeTool:NoSubcommand', ...
        'runProbeTool requires a subcommand (e.g. "list-library").');
end
pythonExe = strtrim(string(pythonExe));
condaEnv = strtrim(string(condaEnv));
if pythonExe == ""
    error('EphysPreprocessingApp:runProbeTool:NoPython', ...
        ['No Python executable configured. Set the Python exe on the ' ...
         'Kilosort tab (the same env used for sorting).']);
end

script = fullfile(fileparts(mfilename('fullpath')), 'probe_tool.py');
if ~isfile(script)
    error('EphysPreprocessingApp:runProbeTool:ScriptMissing', ...
        'probe_tool.py not found next to EphysPreprocessingApp: %s', script);
end

% Double-quote every token; keep native paths (cmd/python handle them as-is),
% mirroring runKilosort's command assembly.
tokens = string(varargin);
quoted = strjoin(arrayfun(@(t) """" + t + """", tokens), " ");
if condaEnv ~= ""
    command = sprintf('conda run -n %s "%s" "%s" %s', condaEnv, pythonExe, script, quoted);
else
    command = sprintf('"%s" "%s" %s', pythonExe, script, quoted);
end

[status, out] = system(command);
raw = string(out);

if status ~= 0 || contains(raw, "PROBE_TOOL_ERROR")
    error('EphysPreprocessingApp:runProbeTool:Failed', ...
        'probe_tool.py %s failed (status %d):\n%s', tokens(1), status, strtrim(raw));
end

result = decodeLastJson(raw);
end


function value = decodeLastJson(raw)
%decodeLastJson  Return the last stdout line that parses as JSON (else the raw
%   text). Scanning from the end skips any leading warnings the env may print
%   (e.g. a first-time probeinterface library download) before the payload.
lines = splitlines(strtrim(raw));
for k = numel(lines):-1:1
    ln = strtrim(lines(k));
    if ln == ""; continue; end
    try
        value = jsondecode(ln);
        return
    catch
        % not this line; keep scanning upward
    end
end
value = raw;   % nothing decoded; hand back what we got
end
