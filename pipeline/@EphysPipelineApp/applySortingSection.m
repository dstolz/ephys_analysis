function applySortingSection(obj, S)
%applySortingSection  Push a config Sorting section into the Sorting tab.
%   Missing fields take the section defaults; typed KS4 values are rendered
%   into the text fields with EphysPipelineConfig.ks4ParamText. The Sorter
%   drop-down shows S.Sorter and, for a SpikeInterface sorter, the text
%   area its parameters (showSorterControls). Values the
%   controls cannot show are reported (setControlValue).
%
%   See also gatherSortingSection.

S = EphysPipelineConfig.normalizeSection("Sorting", S);
if isempty(obj.PythonExeField) || ~isvalid(obj.PythonExeField); return; end
obj.SortEnableCheckBox.Value       = logical(S.Enabled);
obj.SortSkipExistingCheckBox.Value = logical(S.SkipExisting);
if ~isempty(obj.SortSorterDropDown) && isvalid(obj.SortSorterDropDown)
    obj.refreshSorterItems(S.Sorter);   % S.Sorter is listed even when not found
    obj.SortSorterDropDown.Value = char(S.Sorter);
    obj.showSorterControls(S);          % its parameters, or Kilosort4's rows
end
obj.PythonExeField.Value = char(S.PythonExe);
obj.CondaEnvField.Value  = char(S.CondaEnv);
if ~isempty(obj.SortBinDirField) && isvalid(obj.SortBinDirField)
    obj.SortBinDirField.Value = char(S.BinDir);
end
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
F = obj.ReviewCriteriaFields;
for f = string(fieldnames(F)).'
    if ~isvalid(F.(f)); continue; end
    v = S.Quality.(f);
    if isnan(v); F.(f).Value = ''; else; F.(f).Value = char(EphysPipelineConfig.numberText(v)); end
end
end
