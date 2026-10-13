function onPickSessionDatasets(obj, opts)
%onPickSessionDatasets  Pick the datasets the selected session plot draws (Datasets "These datasets").
%   The Pick... button of the Sessions tab's editor: a modal window
%   (private/pickSessionDatasets) lists the scanned datasets by date with
%   their Subject, Date and Key, ticked for the session plot's
%   datasetKeys; OK writes the ticked datasets' keys into datasetKeys (the
%   editor's Keys box, the config, onConfigChanged "sessions": the
%   preview follows). Cancel changes nothing.
%
%   Keys=KEYS (a string array; string.empty for none) skips the window and
%   sets datasetKeys to KEYS as they are, for scripts and tests.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Keys (1,:) string = string(missing)
end
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots)
    obj.setStatus("Sessions: add or select a session plot first.");
    return
end
given = ~(isscalar(opts.Keys) && ismissing(opts.Keys));
if given
    keys = opts.Keys;
else
    if isempty(obj.Runner)
        obj.setStatus("Sessions: scan the datasets first (Data tab).");
        return
    end
    [keys, ok] = pickSessionDatasets(obj.Fig, obj.Runner.sessionTable(), obj.Config.SessionPlots(k).datasetKeys);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
end
cfg = obj.Config;
cfg.SessionPlots(k).datasetKeys = reshape(keys, 1, []);   % the editor has no control for the keys: gatherSessionEditor keeps the config's
obj.Config = cfg;
obj.SessionEditor.datasetKeys.Value = char(strjoin(keys, ", "));
obj.onConfigChanged("sessions");
obj.setStatus(sprintf("Sessions: %s draws %d dataset(s).", cfg.SessionPlots(k).id, numel(keys)));
end
