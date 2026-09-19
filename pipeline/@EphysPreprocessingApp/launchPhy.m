function launchPhy(obj, resultsDir, label)
%launchPhy  Run `phy template-gui params.py` detached in RESULTSDIR.
%   RESULTSDIR must be the folder that holds params.py (for the SpikeInterface
%   engine that is <kilosort4>/si/sorter_output). LABEL names the source in
%   the log (e.g. the dataset name). The launch command comes from the "Phy
%   command" field; phy lives in its own conda env (see INSTALL.md), so the
%   default (when the field is blank) is that env's phy executable, falling
%   back to `conda run -n phy phy` when it cannot be found. phy reads
%   params.py relative to its working directory, so the launcher cd's into
%   the results dir first.
%
%   See also EphysPreprocessingApp.onLaunchPhy, EphysPreprocessingApp.onReviewOpenPhy.

resultsDir = char(resultsDir);
paramsPy   = fullfile(resultsDir, 'params.py');
if ~isfile(paramsPy)
    uialert(obj.Fig, sprintf(['No Kilosort4 results for "%s".' newline ...
        'Expected params.py in:' newline '%s'], label, resultsDir), "phy");
    return
end

phyCmd = strtrim(char(obj.PhyCmdField.Value));
if isempty(phyCmd); phyCmd = defaultPhyCmd(obj); end

% Launch detached. phy resolves params.py against the working directory.
inner = sprintf('%s template-gui params.py', phyCmd);
if ispc
    % start returns 0 even when the command fails, so pause keeps the window
    % open to show the error; cmd /s /c keeps the inner quotes verbatim.
    cmd = sprintf('start "phy" cmd /s /c "cd /d "%s" && %s || pause"', resultsDir, inner);
else
    cmd = sprintf('cd "%s" && %s &', resultsDir, inner);
end

obj.log("Launching phy for %s in %s", label, resultsDir);
obj.log("  %s", inner);
status = system(cmd);
if status ~= 0
    obj.log("  phy launch returned status %d", status);
    uialert(obj.Fig, sprintf(['phy launch returned status %d.' newline ...
        'Check that the Phy command (''%s'') is valid and on PATH.'], ...
        status, phyCmd), "phy");
    return
end
obj.setStatus(sprintf("Launched phy for %s.", label));
end

function phyCmd = defaultPhyCmd(obj)
% phy.exe from the "phy" env when it can be found, so conda need not be on
% PATH; conda installs are located from the Python-exe field, CONDA_EXE, and
% the usual per-user install folders.
roots = strings(0, 1);
py = strtrim(string(obj.PythonExeField.Value));
if py ~= ""
    pyDir = fileparts(py);
    [envsDir, ~] = fileparts(pyDir);
    [condaRoot, envsName] = fileparts(envsDir);
    if strcmpi(envsName, 'envs'); roots(end+1,1) = condaRoot; else; roots(end+1,1) = pyDir; end
end
condaExe = string(getenv('CONDA_EXE'));
if condaExe ~= ""; roots(end+1,1) = fileparts(fileparts(condaExe)); end
roots = [roots; fullfile(string(getenv('LOCALAPPDATA')), 'miniconda3'); ...
    fullfile(string(getenv('USERPROFILE')), ["miniconda3"; "anaconda3"])];
for r = roots'
    exe = fullfile(r, 'envs', 'phy', 'Scripts', 'phy.exe');
    if ~ispc; exe = fullfile(r, 'envs', 'phy', 'bin', 'phy'); end
    if isfile(exe); phyCmd = sprintf('"%s"', exe); return; end
end
phyCmd = 'conda run -n phy phy';
end
