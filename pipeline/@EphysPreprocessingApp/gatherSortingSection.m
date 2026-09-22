function [S, errMsg] = gatherSortingSection(obj)
%gatherSortingSection  The Kilosort tab as a config Sorting section.
%   [S, ERRMSG] = obj.gatherSortingSection() returns EphysPipelineConfig's
%   Sorting struct filled from the controls: paths, execution mode, runs at
%   once and GPUs (on the Run tab), dry run, the typed KS4 parameters (text
%   fields are parsed with EphysPipelineConfig.ks4ParamFromText) and the
%   extra JSON.
%   ERRMSG names the first control whose text does not parse ("" when all
%   parse); S still holds every other value.
%
%   See also applySortingSection, EphysPipelineConfig.ks4Settings.

S = EphysPipelineConfig.defaults("Sorting");
errMsg = "";
if isempty(obj.PythonExeField) || ~isvalid(obj.PythonExeField)
    return
end
S.Enabled      = logical(obj.SortEnableCheckBox.Value);
S.SkipExisting = logical(obj.SortSkipExistingCheckBox.Value);
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
end


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
