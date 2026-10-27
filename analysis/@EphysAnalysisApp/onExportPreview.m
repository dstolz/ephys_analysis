function files = onExportPreview(obj)
%onExportPreview  Write the selected figure for the observation picked as a run would, into a preview folder, and show it.
%   FILES = onExportPreview(obj) is the Figures tab's Export preview button,
%   in its column of buttons and under the preview (Ctrl+K): a spot check of the Export section
%   before a run. The figure in the editor (SelectedFigure), for the
%   observation picked over the preview on the active dataset (a session
%   figure: the matched observation and the figure the "Figure:" drop-down
%   picks, across its datasets), is drawn as a run draws it --
%   newExportFigure at the Export size, renderFigure in the design chosen
%   -- and written by exportFigure in each format ticked at the Export
%   dpi, named as a run names it (figureOutputName;
%   EphysAnalysisRunner.sessionOutputName). The files go to
%   ExportPreviewFolder (emptied first), never the Export folder. The
%   Export controls count as they are (gatherConfig), saved or not, and
%   Write figure files need not be ticked. An out-of-date preview is
%   computed first (refreshFigurePreview, Force), as Open in window does.
%   The Export preview window (ExportPreviewWindow, one, reused) shows the
%   PNG as written (a PNG at the dpi is written for it alone when png is
%   not ticked) under a line with the page's size, the dpi, the pixels, the
%   formats and where a run would write the files (and whether they are
%   there already: kept or replaced, as Overwrite says), with Open the
%   files and Open the folder. FILES = the files written in the formats
%   ticked (empty when none was written).
%
%   See also onOpenFigureWindow, onGenerateFigure, EphysAnalysisRunner.runDataset.
arguments
    obj (1,1) EphysAnalysisApp
end
files = string.empty(1, 0);
if obj.Running
    obj.setStatus("A run is going: preview the export when it is done.");
    return
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])
    obj.setStatus("A preview is computing: preview the export when it is done (or cancel it).");
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure to preview the export of: pick one on the Figures tab, or add one.");
    return
end
if obj.FigurePreviewState ~= "drawn" || isempty(obj.FigurePreviewResult)
    obj.refreshFigurePreview(Force=true);
end
F = obj.FigurePreviewResult;
id = obj.Config.Figures(k).id;
if obj.FigurePreviewState ~= "drawn" || isempty(F) || F.id ~= id
    obj.setStatus("No export preview: " + string(obj.FigurePreviewLabel.Text));
    return
end
cfg = obj.gatherConfig();
X = cfg.Export;
r = obj.Runner;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if cfg.Figures(k).sessions.enabled
    K = obj.FigureSessionResults;
    spec = K.spec;   % as it was computed across the sessions
    e = K.res(find(string({K.res.label}) == K.label, 1));
    fname = EphysAnalysisRunner.sessionOutputName(X.FilenamePattern, spec, T(i, :), e.facet, e.group, i, height(T));
    k1 = r.sessionTable(r.sessionFigureIndices(spec, obj.tickedDatasetIndices())).index(1);
    pattern = X.SessionsFolder;
else
    spec = cfg.figureFor(k);
    spec.enabled = true;
    k1 = obj.ActiveIdx;
    fname = figureOutputName(X.FilenamePattern, r.Names(k1), spec, T(i, :), i, height(T));
    pattern = X.Folder;
end
target = figureFileName(pattern, struct('OutputFolder', r.datasetFolder(k1), 'OutputRoot', r.outputRoot(), ...
    'Root', cfg.Source.Root, 'Name', r.Names(k1)), Kind="folder");
folder = obj.ExportPreviewFolder;
emptyFolder(folder);
obj.setStatus("Writing the export preview of " + id + " (" + string(F.observation.label) + ") ...");
drawnow;
try
    fig = newExportFigure(X, F, spec);
    closer = onCleanup(@() close(fig));
    sizeCm = fig.Position(3:4);   % newExportFigure's units: cm
    renderFigure(F, spec, fig);
    files = exportFigure(fig, fullfile(folder, fname), Format=X.Formats, Dpi=X.Dpi);
    png = files(endsWith(files, ".png"));
    if isempty(png)
        png = exportFigure(fig, fullfile(folder, "view", fname), Format="png", Dpi=X.Dpi);   % only for the window
    end
    clear closer
catch ME
    files = string.empty(1, 0);
    obj.log("Export preview failed: " + string(ME.message));
    obj.setStatus("The export preview of " + id + " failed: " + string(ME.message));
    return
end
img = imread(png);
info = previewInfo(X, fname, target, files, sizeCm, size(img, [2 1]));
showWindow(obj, img, info, files, folder, id + ": " + string(F.observation.label));
obj.setStatus(sprintf("Export preview of %s (%s): %d file(s) in %s; a run writes them to %s.", id, ...
    string(F.observation.label), numel(files), folder, target));
end


function info = previewInfo(X, fname, target, files, sizeCm, px)
%previewInfo  The window's lines: the page's size, dpi and pixels, the formats; where a run writes them, kept or replaced.
fmts = X.Formats;
if isempty(fmts)
    line1 = "No format is ticked: a run writes no figure file (the PNG shown is only for this preview).";
else
    line1 = sprintf("%s:  %.3g x %.3g cm  at %g dpi  (%d x %d px)", strjoin(fname + "." + fmts, ", "), sizeCm, X.Dpi, px);
end
want = fullfile(target, fname) + "." + fmts;
line2 = "A run writes them to " + target;
there = isfile(want);
if any(there)
    if X.Overwrite
        line2 = line2 + sprintf(" (%d there already, replaced: Overwrite is on)", nnz(there));
    else
        line2 = line2 + sprintf(" (%d there already, kept: Overwrite is off)", nnz(there));
    end
end
if ~X.Enabled
    line2 = line2 + ", once Write figure files is ticked";
end
line3 = "This preview: " + strjoin(files, ", ");
if isempty(files); line3 = ""; end
info = [line1; line2 + "."; line3];
info = info(info ~= "");
end


function showWindow(obj, img, info, files, folder, name)
%showWindow  The Export preview window: the lines, the PNG at its size (scaled down to fit), Open the files, Open the folder.
w = obj.ExportPreviewWindow;
scr = get(groot, 'ScreenSize');
sz = [max(size(img, 2) + 24, 560), size(img, 1) + 24 + 22 * numel(info) + 50];
sz = min(sz, floor(0.9 * scr(3:4)));
if isempty(w) || ~isvalid(w)
    w = uifigure("Position", [max(1, round((scr(3:4) - sz) / 2)) sz]);
    obj.ExportPreviewWindow = w;
else
    delete(w.Children);
    w.Position(3:4) = sz;
end
w.Name = char("Export preview: " + name);
g = uigridlayout(w, [3 1], "RowHeight", {'fit', '1x', 30}, "Padding", [10 10 10 10], "RowSpacing", 6);
uilabel(g, "Text", info, "WordWrap", "on");
uiimage(g, "ImageSource", img, "ScaleMethod", "scaledown", ...
    "Tooltip", "The figure as a run writes it (scaled down when it is larger than the window).");
bg = uigridlayout(g, [1 3], "ColumnWidth", {'fit', 'fit', '1x'}, "Padding", [0 0 0 0]);
b = uibutton(bg, "Text", "Open the files", "Enable", matlab.lang.OnOffSwitchState(~isempty(files)), ...
    "Tooltip", "Open each file written in its own program (an SVG or EPS shows how it comes out of MATLAB).", ...
    "ButtonPushedFcn", @(~,~) arrayfun(@openInSystem, files));
styleButton(b);
b = uibutton(bg, "Text", "Open the folder", "ButtonPushedFcn", @(~,~) openInSystem(folder), ...
    "Tooltip", "The preview folder: emptied by the next Export preview.");
styleButton(b);
figure(w);
end


function emptyFolder(folder)
%emptyFolder  The preview folder's figure files (and its view folder's) deleted; the folder made when missing.
if ~isfolder(folder); mkdir(folder); return; end
old = [dir(fullfile(folder, "*.*")); dir(fullfile(folder, "view", "*.*"))];
old = old(~[old.isdir] & endsWith(lower(string({old.name})), [".png" ".eps" ".svg" ".pdf"]));
for j = 1:numel(old)
    delete(fullfile(old(j).folder, old(j).name));
end
end
