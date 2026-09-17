function P = gatherParallelSection(obj)
%gatherParallelSection  Parallel section from the Run tab's controls.
P = obj.Config.Parallel;
P.Enabled = logical(obj.RunParallelCheckBox.Value);
t = strtrim(string(obj.RunMaxWorkersField.Value));
if t == "" || any(lower(t) == ["auto" "nan"])
    P.MaxWorkers = NaN;
else
    v = str2double(t);
    if isnan(v)
        error('EphysPreprocessingApp:ParallelNumber', 'Max workers "%s" is not a number.', t);
    end
    P.MaxWorkers = v;
end
end
