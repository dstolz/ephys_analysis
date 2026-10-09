function applyAnalysisCopySection(obj, X)
%applyAnalysisCopySection  AnalysisCopy section -> the Run tab's box.
X = EphysPipelineConfig.normalizeSection("AnalysisCopy", X);
obj.RunAnalysisCopyCheckBox.Value = logical(X.Enabled);
end
