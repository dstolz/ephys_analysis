function onCopyFigureSettings(obj, opts)
%onCopyFigureSettings  Copy another figure's settings, part by part, onto the selected figure.
%   The figure list's "Copy from..." button: a modal window
%   (private/pickFigureSettings) offers the other figures and a box per
%   part of their settings (figureSettingParts: Observations, Alignment,
%   Arrangement and panels, Appearance, Remembered looks, Across
%   sessions).
%   Copy gives the selected figure the ticked parts of the figure picked
%   (copyFigureSettings); it keeps its id, title and enabled. The editor,
%   the observation picker and the preview follow; the status bar says
%   what was copied.
%
%   From=ID (a figure id) skips the window, with Parts=PARTS
%   (figureSettingParts' Part names; default every part), for scripts and
%   tests.
arguments
    obj (1,1) EphysAnalysisApp
    opts.From (1,1) string = string(missing)
    opts.Parts string = string(missing)
end
k = obj.SelectedFigure;
cfg = obj.gatherConfig();
if k < 1 || k > numel(cfg.Figures) || numel(cfg.Figures) < 2
    obj.setStatus("Copy settings: select a figure, with another figure left to copy from.");
    return
end
if ismissing(opts.From)
    [from, parts, ok] = pickFigureSettings(obj.Fig, cfg.Figures, k);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
else
    from = cfg.figureIndex(opts.From);
    if from < 1 || from == k
        obj.setStatus("Copy settings: no other figure """ + opts.From + """ to copy from.");
        return
    end
    parts = opts.Parts;
end
src = cfg.Figures(from);
try
    [cfg.Figures(k), copied] = copyFigureSettings(cfg.Figures(k), src, parts);
catch ME
    obj.setStatus("Copy settings: " + string(ME.message));
    return
end
if ismember("arrangement", copied)
    obj.SelectedPanel = 1;
    obj.SelectedLayer = 1;
end
obj.applyConfig(cfg, Action="Copy settings");
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
T = figureSettingParts();
labels = T.Label(ismember(T.Part, copied)).';
if isempty(labels)
    obj.setStatus("Nothing copied from " + src.id + ".");
else
    obj.setStatus("Copied from " + src.id + " onto " + cfg.Figures(k).id + ": " + strjoin(labels, ", ") + ".");
end
obj.autoFigurePreview();
end
