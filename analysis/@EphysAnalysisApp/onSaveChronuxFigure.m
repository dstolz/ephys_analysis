function file = onSaveChronuxFigure(obj, file)
%onSaveChronuxFigure  Save the Chronux tab's page shown as a figure file: png, pdf, svg or eps.
%   FILE "" asks where (uiputfile). The plot is drawn again into an
%   invisible classic figure of the export size (newExportFigure, the
%   Export tab's figure size) and written by exportFigure.
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
R = obj.ChronuxResult;
if isempty(R); return; end
if file == ""
    base = R.dataset + "_" + R.kind;
    [f, p] = uiputfile({'*.png', 'PNG image'; '*.pdf', 'PDF'; '*.svg', 'SVG'; '*.eps', 'EPS'}, ...
        "Save the Chronux figure", fullfile(obj.LastExportFolder, base + ".png"));
    if isequal(f, 0); file = ""; return; end
    file = string(fullfile(p, f));
end
[folder, base, ext] = fileparts(file);
fmt = lower(erase(string(ext), "."));
if fmt == ""; fmt = "png"; end
try
    S = obj.gatherChronuxSettings();
    d = S.display;
catch
    d = R.settings.display;
end
d.page = obj.ChronuxPage;
fig = newExportFigure(obj.Config.Export);
closer = onCleanup(@() close(fig));
renderChronux(R, fig, Display=d, Editable=false);
exportFigure(fig, fullfile(folder, base), Format=fmt);
obj.log("Chronux: figure saved to " + file);
obj.setStatus("Saved " + file);
end
