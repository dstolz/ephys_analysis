function onBrowsePython(obj)
    % Prompt for the python/conda executable.
    [f, p] = uigetfile({'*.exe;python*', 'Executable'}, "Select python executable");
    figure(obj.Fig);
    if isequal(f, 0); return; end
    obj.PythonExeField.Value = fullfile(p, f);
    setpref(obj.PrefGroup, 'PythonExe', fullfile(p, f));   % new configs start from it
    obj.onConfigChanged();
end
