function applyAnalysisSection(obj, A)
%applyAnalysisSection  Analysis section -> Analysis tab (and the summary of its config file).
A = EphysPipelineConfig.normalizeSection("Analysis", A);
obj.AnaEnableCheckBox.Value  = logical(A.Enabled);
obj.AnaConfigField.Value     = char(A.ConfigFile);
obj.AnaFiguresCheckBox.Value = logical(A.Figures);
obj.AnaReportCheckBox.Value  = logical(A.Report);
obj.refreshAnalysisSummary();
end
