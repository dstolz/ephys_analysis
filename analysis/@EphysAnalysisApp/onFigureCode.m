function txt = onFigureCode(obj, file)
%onFigureCode  The code that draws the figure preview, opened in the MATLAB editor.
%   TXT = onFigureCode(obj) is the Figures tab's "Export code" button, at
%   the right of the row over the Dataset drop-down: the script of
%   EphysAnalysisScript.preview for the selected figure, the active dataset
%   (a figure across sessions: the ticked or listed datasets, as the
%   preview draws it), the observation picked (and the "Figure:" pick under
%   the preview), the design chosen and the preview's size, opened as a
%   new, unsaved document in the MATLAB editor. It draws the figure in a
%   window of its own as the preview draws it, through the analysis
%   functions (figureCompute, renderFigure), not the app or the runner.
%   Nothing is computed here, so the preview need not be drawn. With FILE,
%   or without the desktop's editor (matlab -batch: a file in tempdir), the
%   code is written to the file instead and the status bar names it. TXT is
%   the code, "" when there is nothing to write it for (the status bar says
%   why).
%
%   See also EphysAnalysisScript.preview, refreshFigurePreview, onOpenFigureWindow.
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
txt = "";
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure to write the code for: add one first.");
    return
end
fg = obj.Config.Figures(k);
rn = obj.Runner;
if isempty(rn) || isempty(rn.Keys)
    obj.setStatus("Scan for datasets first: the code reads one of them.");
    return
end
if fg.sessions.enabled
    idx = rn.sessionFigureIndices(obj.Config.figureFor(k), obj.tickedDatasetIndices());
    if isempty(idx)
        obj.setStatus("No dataset is ticked or listed to draw " + fg.id + " across: tick some on the Data tab.");
        return
    end
else
    idx = obj.ActiveIdx;
    if idx < 1
        obj.setStatus("Pick a dataset first: the code reads it.");
        return
    end
end
obj.refreshFigureObservations();   % the picker as the preview has it (kept while it is up to date)
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
obs = [];
if istable(T) && isnumeric(i) && isscalar(i) && i >= 1 && i <= height(T); obs = T(i, :); end
entry = "";
K = obj.FigureSessionResults;
if fg.sessions.enabled && isstruct(K) && isfield(K, 'label') && K.spec.id == fg.id; entry = K.label; end
pos = getpixelposition(obj.FigurePreviewPanel, true);
cfg = obj.Config;
cfg.Source = rn.Config.Source;   % the datasets as scanned: the keys are the runner's
try
    txt = EphysAnalysisScript.preview(cfg, fg.id, Datasets=rn.Keys(idx), Observation=obs, Entry=entry, ...
        Design=PlotDesign.currentName(), Size=max(round(pos(3:4)), [400 300]));
catch ME
    uialert(obj.Fig, "Could not write the code:" + newline + string(ME.message), "Export code");
    return
end
editor = false;
if file == "" && ~batchStartupOptionUsed   % (under -batch the editor API answers as if there were one)
    try
        editor = matlab.desktop.editor.isEditorAvailable();
    catch
    end
end
if editor
    matlab.desktop.editor.newDocument(char(txt));
    obj.setStatus("The code that draws " + fg.id + " is in the editor, unsaved: run it to draw the figure in a window of its own.");
    return
end
if file == ""; file = string(fullfile(tempdir, matlab.lang.makeValidName("preview_" + fg.id) + ".m")); end
EphysAnalysisScript.write(file, txt);
obj.setStatus("Wrote the code that draws " + fg.id + " to " + file + ".");
end
