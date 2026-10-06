function [S, errMsg] = gatherSortingSection(obj)
%gatherSortingSection  The Sorting tab as a config Sorting section.
%   [S, ERRMSG] = obj.gatherSortingSection() returns EphysPipelineConfig's
%   Sorting struct filled from the controls: paths, execution mode, runs at
%   once and GPUs (on the Run tab), dry run, the typed KS4 parameters (text
%   fields are parsed with EphysPipelineConfig.ks4ParamFromText) and the
%   extra JSON, the sorter (Sorting.Sorter) and the parameters of the
%   SpikeInterface sorter shown (Sorting.SIParams.<sorter>; "" when they are
%   its defaults), and the good-unit criteria (Sorting.Quality) of the
%   Review tab.
%   ERRMSG names the first control whose text does not parse ("" when all
%   parse); that parameter keeps the working config's value in S, and
%   gatherConfig refuses the config (so do Run and Save).
%
%   See also applySortingSection, EphysPipelineConfig.ks4Settings.

S = obj.Config.Sorting;
errMsg = "";
if isempty(obj.PythonExeField) || ~isvalid(obj.PythonExeField)
    return
end
S.Enabled      = logical(obj.SortEnableCheckBox.Value);
S.SkipExisting = logical(obj.SortSkipExistingCheckBox.Value);
if ~isempty(obj.SortSorterDropDown) && isvalid(obj.SortSorterDropDown)
    S.Sorter = string(obj.SortSorterDropDown.Value);
end
if obj.SIParamsShown ~= "" && ~isempty(obj.SIParamsArea) && isvalid(obj.SIParamsArea)
    % The parameters shown belong to SIParamsShown (the sorter shown until
    % the drop-down changed, see onSorterChanged). SpikeInterface's
    % defaults, or no parameters at all, are stored as "" (the defaults).
    raw = strtrim(strjoin(string(obj.SIParamsArea.Value(:)), newline));
    def = obj.siDefaultParams(obj.SIParamsShown);
    if regexprep(raw, '\s', '') == "{}" || (def ~= "" && regexprep(raw, '\s', '') == regexprep(def, '\s', ''))
        raw = "";
    end
    problem = EphysDataset.sorterParamsProblem(raw);
    if problem ~= ""
        errMsg = obj.SIParamsShown + " parameters: " + problem;   % the working config's stay
    else
        S.SIParams.(obj.SIParamsShown) = raw;
    end
end
S.PythonExe = string(strtrim(obj.PythonExeField.Value));
S.CondaEnv  = string(strtrim(obj.CondaEnvField.Value));
if ~isempty(obj.ExecModeDropDown) && isvalid(obj.ExecModeDropDown)
    if logical(obj.ExecModeDropDown.Value); S.Execution = "blocking"; else; S.Execution = "background"; end
end
if ~isempty(obj.RunKSAtOnceSpinner) && isvalid(obj.RunKSAtOnceSpinner)
    S.MaxConcurrent = double(obj.RunKSAtOnceSpinner.Value);   % on the Run tab
end
if ~isempty(obj.RunKSDevicesField) && isvalid(obj.RunKSDevicesField)   % on the Run tab too
    dev = split(strtrim(string(obj.RunKSDevicesField.Value)), [",", ";", " "]).';
    S.Devices = dev(dev ~= "");
end
if ~isempty(obj.DryRunCheckBox) && isvalid(obj.DryRunCheckBox)
    S.DryRun = logical(obj.DryRunCheckBox.Value);
end

spec = EphysPipelineConfig.kilosortParamSpec();
for i = 1:numel(spec)
    p = spec(i);
    if ~isfield(obj.ParamControls, p.name); continue; end
    v = obj.ParamControls.(p.name).Value;
    switch p.kind
        case 'bool'
            S.KS4.(p.name) = logical(v);
        case {'int', 'float'}
            S.KS4.(p.name) = double(v);
        otherwise
            [val, ok] = EphysPipelineConfig.ks4ParamFromText(p.kind, v);
            if ~ok
                if errMsg == ""
                    errMsg = string(p.label) + ": '" + string(v) + "' is not a " + ...
                        ternary(strcmp(p.kind, 'vector'), "numeric list", "number") + ".";
                end
                continue
            end
            S.KS4.(p.name) = val;
    end
end
if ~isempty(obj.ExtraSettingsArea) && isvalid(obj.ExtraSettingsArea)
    raw = strtrim(strjoin(string(obj.ExtraSettingsArea.Value(:)), newline));
    if raw == "{}" || all(strtrim(splitlines(raw)) == "") || regexprep(raw, '\s', '') == "{}"
        raw = "";
    end
    S.KS4ExtraJSON = raw;
end
% Good-unit criteria (Review tab): blank = not applied (NaN)
F = obj.ReviewCriteriaFields;
for f = string(fieldnames(F)).'
    if ~isvalid(F.(f)); continue; end
    t = strtrim(string(F.(f).Value));
    if t == ""
        S.Quality.(f) = NaN;
        continue
    end
    v = str2double(t);
    if isnan(v) || v < 0
        if errMsg == ""
            errMsg = "Good-unit criterion """ + f + """ must be a number of at least 0, or blank (got """ + t + """).";
        end
        continue
    end
    S.Quality.(f) = v;
end
end


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
