function applyExportSection(obj, X)
%applyExportSection  Show config Export on the Export tab.
C = obj.ExportControls;
C.Enabled.Value = X.Enabled;
for f = ["png" "eps" "svg" "pdf"]
    C.(f).Value = ismember(f, X.Formats);
end
C.Folder.Value = char(X.Folder);
C.FilenamePattern.Value = char(X.FilenamePattern);
C.Dpi.Value = X.Dpi;
C.Width.Value = X.FigureSizeCm(1);
C.Height.Value = X.FigureSizeCm(2);
C.Overwrite.Value = X.Overwrite;
end
