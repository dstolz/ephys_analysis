function A = gatherAnalysisSection(obj)
%gatherAnalysisSection  Analysis section from the Analysis tab.
A = obj.Config.Analysis;
A.Enabled    = logical(obj.AnaEnableCheckBox.Value);
A.ConfigFile = string(strtrim(obj.AnaConfigField.Value));
A.Figures    = logical(obj.AnaFiguresCheckBox.Value);
A.Report     = logical(obj.AnaReportCheckBox.Value);
end
