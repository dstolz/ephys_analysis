function refreshSessionPreview(obj)
%refreshSessionPreview  Compute the selected session plot over its datasets and draw it.
%   Goes through the runner (computeSessionPlot: the base plot on every
%   session, cached per dataset, merged by sessionResults; then
%   renderPlotFigures into the Sessions tab's preview panel), so the
%   preview is what a run draws. Its datasets are the ticked ones, or the
%   session plot's own list. Every page and every figure (one per subject
%   with Figures "One per subject", one per trial group with "A figure per
%   group") is computed: the figure box and < > only draw (drawSessionPreview).
%   A right-click on the preview opens the aesthetics editor; what it
%   remembers goes to the session plot's own aesthetics
%   (rememberSessionAesthetics), never to the base plot's. The badge
%   (setSessionPreviewState) says Computing, then Drawing, with a card over
%   the old plot, and how it ended; the card's Cancel button
%   (onCancelSessionPreview) stops the compute between sessions (the
%   runner polls, Runner.PollFcn). Edits made meanwhile leave it Out of
%   date. Nothing is computed while a run goes or the Plots tab's preview
%   computes.
arguments
    obj (1,1) EphysAnalysisApp
end
if ismember(obj.SessionPreviewState, ["computing" "drawing"])
    obj.SessionPreviewRedo = true;
    return
end
L = obj.SessionPreviewLabel;
cfg = obj.Config;
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(cfg.SessionPlots)
    obj.SessionPreviewResults = [];
    fillFigures(obj);
    clearSessionPanel(obj, "No session plot selected: pick a base plot under the list and press Add.");
    obj.setSessionPreviewState("idle");
    return
end
if isempty(obj.Runner)
    obj.SessionPreviewResults = [];
    fillFigures(obj);
    clearSessionPanel(obj, "Scan the datasets to preview (Data tab).");
    obj.setSessionPreviewState("idle");
    return
end
if obj.Running
    L.Text = "A run is going: preview the session plot when it is done.";
    return
end
if ismember(obj.PreviewState, ["computing" "drawing"])   % called from inside the Plots tab's preview (its polling)
    L.Text = "The Plots tab's preview is computing: press Preview when it is done.";
    return
end
sp = cfg.SessionPlots(k);
b = cfg.plotIndex(sp.plot);
reason = "";
if b == 0
    reason = "its base plot """ + sp.plot + """ is not in the config";
elseif ~ismember(cfg.Plots(b).kind, EphysAnalysisConfig.SessionKinds)
    reason = "a " + cfg.Plots(b).kind + " plot cannot be merged across sessions";
end
idx = [];
if reason == ""
    if sp.datasets == "list"
        n = numel(sp.datasetKeys);
        if n == 0; reason = "it lists no dataset (Pick...)"; end
    else
        idx = obj.tickedDatasetIndices();
        n = numel(idx);
        if n == 0; reason = "no dataset is ticked (Data tab)"; end
    end
end
if reason ~= ""
    obj.SessionPreviewResults = [];
    fillFigures(obj);
    clearSessionPanel(obj, sp.id + " cannot be drawn: " + reason + ".");
    obj.setSessionPreviewState("skipped");
    return
end
shown = "";   % the figure shown before, shown again when it is still there
if ~isempty(obj.SessionPreviewResults) && obj.SessionPreviewIndex >= 1 && obj.SessionPreviewIndex <= numel(obj.SessionPreviewResults)
    shown = obj.SessionPreviewResults(obj.SessionPreviewIndex).label;
end
msg = sprintf("Computing %s on %d session(s) ...", sp.id, n);
L.Text = msg;
rn = obj.Runner;
rn.clearCancel();   % before the badge paints: a click on Cancel can come in while it does
obj.SessionPreviewRedo = false;
obj.setSessionPreviewState("computing", Message=msg);
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
polling = onCleanup(@() stopPolling(rn));
try
    [res, sessions] = rn.computeSessionPlot(sp, idx, KeepActive=obj.ActiveIdx);
    rn.PollFcn = [];
    obj.SessionPreviewResults = res;
    i = [];
    if ~isempty(res); i = find([res.label] == shown, 1); end
    if isempty(i) && ~isempty(res); i = find([res.status] == "done", 1); end
    if isempty(i); i = 1; obj.SessionPreviewPage = 1; end
    if i ~= obj.SessionPreviewIndex; obj.SessionPreviewPage = 1; end
    obj.SessionPreviewIndex = i;
    fillFigures(obj);
    L.Text = "Drawing " + sp.id + " ...";
    obj.setSessionPreviewState("drawing", Message="Drawing " + sp.id + " ...");
    state = obj.drawSessionPreview();
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end   % the app was closed while it computed
    obj.SessionPreviewResults = [];
    fillFigures(obj);
    obj.SessionPreviewSeconds = Inf;
    if ME.identifier == "EphysAnalysisRunner:Canceled"
        clearSessionPanel(obj, sp.id + " was canceled: press Preview to compute it.");
        obj.log(sp.id + " session preview canceled.");
        obj.setSessionPreviewState("canceled");
        return
    end
    clearSessionPanel(obj, sp.id + " failed: " + string(ME.message));
    obj.log(sp.id + " session preview failed: " + string(ME.message));
    obj.setSessionPreviewState("failed");
    return
end
obj.SessionPreviewSeconds = toc(t0);
obj.setSessionPreviewState(state);
if state ~= "drawn"; return; end
if obj.SessionPreviewRedo; obj.setSessionPreviewState("stale"); end
nDone = nnz(sessions.status == "done");
L.Text = sprintf("%s over %d of %d session(s) (%.1f s); right-click the plot to change its look (kept with the session plot)", ...
    sp.id, nDone, height(sessions), obj.SessionPreviewSeconds);
if nDone < height(sessions)
    out = sessions.status ~= "done";
    L.Text = L.Text + "; left out: " + strjoin(string(sessions.label(out)) + " (" + string(sessions.message(out)) + ")", "; ");
end
if obj.SessionPreviewSeconds >= obj.AutoPreviewSeconds && obj.SessionAutoCheckBox.Value
    L.Text = L.Text + "; slow, so edits wait for Preview";
end
end


function stopPolling(rn)
if isvalid(rn); rn.PollFcn = []; end
end


function fillFigures(obj)
%fillFigures  The figure box: one entry per figure the session plot makes (shown while there are several).
res = obj.SessionPreviewResults;
dd = obj.SessionGroupDropDown;
if isempty(res)
    set(dd, "Items", "all", "ItemsData", 1, "Value", 1);
    dd.Parent.Visible = "off";
    return
end
labels = [res.label];
off = [res.status] ~= "done";
labels(off) = labels(off) + "  (" + [res(off).status] + ")";
set(dd, "Items", labels, "ItemsData", 1:numel(res), "Value", obj.SessionPreviewIndex);
dd.Parent.Visible = matlab.lang.OnOffSwitchState(numel(res) > 1);
end
