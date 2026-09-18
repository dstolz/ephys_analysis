function X = gatherExportSection(obj)
%gatherExportSection  Config Export from the Export tab.
C = obj.ExportControls;
fmts = ["png" "eps" "svg" "pdf"];
fmts = fmts(arrayfun(@(f) C.(f).Value, fmts));
if isempty(fmts); fmts = string.empty(1, 0); end
X = obj.Config.Export;
X.Enabled = C.Enabled.Value;
X.Formats = fmts;
X.Folder = strtrim(string(C.Folder.Value));
X.FilenamePattern = strtrim(string(C.FilenamePattern.Value));
X.Dpi = C.Dpi.Value;
X.FigureSizeCm = [C.Width.Value C.Height.Value];
X.Overwrite = C.Overwrite.Value;
end
