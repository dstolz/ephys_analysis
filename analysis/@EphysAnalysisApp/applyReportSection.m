function applyReportSection(obj, P)
%applyReportSection  Show config Report on the Export tab.
C = obj.ReportControls;
C.Enabled.Value = P.Enabled;
C.Format.Value = char(P.Format);
C.Title.Value = char(P.Title);
C.Folder.Value = char(P.Folder);
C.FileName.Value = char(P.FileName);
C.PerDataset.Value = P.PerDataset;
C.EmbedFormat.Value = char(P.EmbedFormat);
C.Dpi.Value = P.Dpi;
C.IncludeSummary.Value = P.IncludeSummary;
C.IncludeParameters.Value = P.IncludeParameters;
C.IncludeConfig.Value = P.IncludeConfig;
end
