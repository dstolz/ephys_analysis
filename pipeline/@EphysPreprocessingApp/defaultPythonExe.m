function p = defaultPythonExe(obj)
    % Best-guess python for the Kilosort4 sorting step, used to seed the
    % Python-exe field of a new config (the user can override): the last
    % python set in the app (preference 'PythonExe', written whenever the
    % field holds an existing file), else the "kilosort" conda env python
    % in the usual conda install folders, else "".
    p = "";
    g = obj.PrefGroup;
    if ispref(g, 'PythonExe')
        c = string(getpref(g, 'PythonExe'));
        if isscalar(c) && c ~= "" && isfile(c); p = c; return; end
    end
    roots = string.empty(1, 0);
    condaExe = string(getenv('CONDA_EXE'));   % <root>\Scripts\conda.exe
    if condaExe ~= ""; roots(end+1) = fileparts(fileparts(condaExe)); end
    for base = string({getenv('LOCALAPPDATA'), getenv('USERPROFILE'), getenv('ProgramData'), 'C:\'})
        if base == ""; continue; end
        roots = [roots, fullfile(base, ["miniconda3" "anaconda3" "miniforge3" "mambaforge"])]; %#ok<AGROW>
    end
    for r = roots
        c = fullfile(r, 'envs', 'kilosort', 'python.exe');
        if isfile(c); p = c; return; end
    end
end
