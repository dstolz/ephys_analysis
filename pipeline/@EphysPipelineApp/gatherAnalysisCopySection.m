function X = gatherAnalysisCopySection(obj)
%gatherAnalysisCopySection  AnalysisCopy section (copy the files for the analysis app after a Run) from the Run tab's box.
X = obj.Config.AnalysisCopy;
X.Enabled = logical(obj.RunAnalysisCopyCheckBox.Value);
end
