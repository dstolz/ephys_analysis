function onPickFigureDatasets(obj, opts)
%onPickFigureDatasets  Pick the datasets the selected session figure is drawn across (Sessions: "These datasets").
%   The Pick... button of the Figures tab's Sessions section: a window
%   (private/pickSessionDatasets) lists
%   the scanned datasets by date with their Subject, Date and Key, ticked
%   for the figure's sessions.datasetKeys; OK writes the ticked datasets'
%   keys there (the Keys box, the config, onConfigChanged "figure": the
%   picker and the preview follow; a step of the undo history,
%   recordFigureEdit). Cancel changes nothing.
%
%   Keys=KEYS (a string array; string.empty for none) skips the window and
%   sets sessions.datasetKeys to KEYS as they are, for scripts and tests.
%
%   See also figureSessionObservations, sessionTable.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Keys (1,:) string = string(missing)
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("Figures: add or select a figure first.");
    return
end
given = ~(isscalar(opts.Keys) && ismissing(opts.Keys));
if given
    keys = opts.Keys;
else
    if isempty(obj.Runner)
        obj.setStatus("Figures: scan the datasets first (Data tab).");
        return
    end
    [keys, ok] = pickSessionDatasets(obj.Fig, obj.Runner.sessionTable(), obj.Config.Figures(k).sessions.datasetKeys);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
end
cfg = obj.Config;
cfg.Figures(k).sessions.datasetKeys = reshape(keys, 1, []);   % no control holds the keys: gatherFigureEditor keeps the config's
recordFigureEdit(obj, cfg, "Pick datasets");
obj.Config = cfg;
obj.FigureEditor.sesKeys.Value = char(strjoin(keys, ", "));
obj.onConfigChanged("figure", "Pick datasets");
obj.setStatus(sprintf("Figures: %s is drawn across %d dataset(s).", cfg.Figures(k).id, numel(keys)));
end
