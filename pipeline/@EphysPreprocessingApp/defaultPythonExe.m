function p = defaultPythonExe(~)
    % Best-guess python for the Kilosort4 sorting step: the
    % "kilosort" conda env python when present, else "". Used to seed the
    % Python-exe field on first launch (the user can override).
    p = "";
    cands = string(fullfile(getenv('LOCALAPPDATA'), 'miniconda3', 'envs', 'kilosort', 'python.exe'));
    cands(end+1) = string(fullfile(getenv('USERPROFILE'), 'miniconda3', 'envs', 'kilosort', 'python.exe'));
    cands(end+1) = string(fullfile(getenv('USERPROFILE'), 'anaconda3', 'envs', 'kilosort', 'python.exe'));
    for c = cands
        if isfile(c); p = c; return; end
    end
end
