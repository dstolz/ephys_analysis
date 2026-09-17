function applyParallelSection(obj, P)
%applyParallelSection  Parallel section -> Run tab controls.
P = EphysPipelineConfig.normalizeSection("Parallel", P);
obj.RunParallelCheckBox.Value = logical(P.Enabled);
if isnan(P.MaxWorkers)
    obj.RunMaxWorkersField.Value = '';
else
    obj.RunMaxWorkersField.Value = char(string(P.MaxWorkers));
end
obj.RunMaxWorkersField.Enable = matlab.lang.OnOffSwitchState(logical(P.Enabled));
end
