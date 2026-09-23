function applySortingSection(obj, S)
%applySortingSection  Push a config Sorting section into the Kilosort tab.
%   Missing fields take the section defaults; typed KS4 values are rendered
%   into the text fields with EphysPipelineConfig.ks4ParamText. Values the
%   controls cannot show are reported (setControlValue).
%
%   See also gatherSortingSection.

S = EphysPipelineConfig.normalizeSection("Sorting", S);
if isempty(obj.PythonExeField) || ~isvalid(obj.PythonExeField); return; end
obj.SortEnableCheckBox.Value       = logical(S.Enabled);
obj.SortSkipExistingCheckBox.Value = logical(S.SkipExisting);
obj.PythonExeField.Value = char(S.PythonExe);
obj.CondaEnvField.Value  = char(S.CondaEnv);
if ~isempty(obj.ExecModeDropDown) && isvalid(obj.ExecModeDropDown)
    obj.ExecModeDropDown.Value = (S.Execution == "blocking");
end
if ~isempty(obj.RunKSAtOnceSpinner) && isvalid(obj.RunKSAtOnceSpinner)
    obj.setControlValue(obj.RunKSAtOnceSpinner, S.MaxConcurrent, "Sorting.MaxConcurrent");
    obj.RunKSAtOnceSpinner.Enable = matlab.lang.OnOffSwitchState(S.Execution == "background");
end
if ~isempty(obj.RunKSDevicesField) && isvalid(obj.RunKSDevicesField)
    obj.RunKSDevicesField.Value = char(strjoin(S.Devices, ", "));
end
if ~isempty(obj.RunKSQueueCheckBox) && isvalid(obj.RunKSQueueCheckBox)
    obj.RunKSQueueCheckBox.Enable = matlab.lang.OnOffSwitchState(S.Execution == "background");
end
if ~isempty(obj.DryRunCheckBox) && isvalid(obj.DryRunCheckBox)
    obj.DryRunCheckBox.Value = logical(S.DryRun);
end

spec = EphysPipelineConfig.kilosortParamSpec();
for i = 1:numel(spec)
    p = spec(i);
    if ~isfield(obj.ParamControls, p.name) || ~isfield(S.KS4, p.name); continue; end
    ctrl = obj.ParamControls.(p.name);
    v = S.KS4.(p.name);
    switch p.kind
        case 'bool'
            ctrl.Value = logical(v);
        case {'int', 'float'}
            obj.setControlValue(ctrl, double(v), "Sorting.KS4." + p.name);
        otherwise
            ctrl.Value = char(EphysPipelineConfig.ks4ParamText(p.kind, v));
    end
end
if ~isempty(obj.ExtraSettingsArea) && isvalid(obj.ExtraSettingsArea)
    txt = S.KS4ExtraJSON;
    if txt == ""; txt = "{" + newline + "}"; end
    obj.ExtraSettingsArea.Value = cellstr(splitlines(txt));
end
end
