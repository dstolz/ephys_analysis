function P = gatherReportSection(obj)
%gatherReportSection  Config Report from the Export tab.
C = obj.ReportControls;
P = obj.Config.Report;
P.Enabled = C.Enabled.Value;
P.Format = string(C.Format.Value);
P.Title = string(C.Title.Value);
P.Folder = strtrim(string(C.Folder.Value));
P.FileName = strtrim(string(C.FileName.Value));
P.PerDataset = C.PerDataset.Value;
P.EmbedFormat = string(C.EmbedFormat.Value);
P.Dpi = C.Dpi.Value;
P.IncludeSummary = C.IncludeSummary.Value;
P.IncludeParameters = C.IncludeParameters.Value;
P.IncludeConfig = C.IncludeConfig.Value;
end
