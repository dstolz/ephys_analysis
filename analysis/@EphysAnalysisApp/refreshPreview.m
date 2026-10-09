function refreshPreview(obj, opts)
%refreshPreview  Compute and draw the selected plot on the active dataset.
%   Goes through the runner (computePlot, then renderPlotFigures into the
%   preview panel), so the preview is what a run draws. A plot the dataset
%   cannot draw says why; a signal extract above PreviewMaxMB is only read
%   when Force is set (the Preview button). The time taken decides whether
%   edits redraw it (auto-preview under AutoPreviewSeconds). A right-click
%   on any part of the preview opens the aesthetics editor; what it
%   remembers for the plot comes back through rememberAesthetics. The
%   badge under it (setPreviewState) says Computing, then Drawing, with a
%   card over the old plot, and how it ended. The card's Cancel button
%   (onCancelPreview) stops the compute: it polls (Runner.PollFcn, drawnow
%   limitrate) so the button's callback runs in the middle of it, and the
%   edits made meanwhile come in too; they do not start a second preview,
%   but leave this one Out of date.
%   A grid of units or channels is computed for the page shown only
%   (computePlot Page=); < and > then compute the page they go to.
%   AllPages (Ctrl+click on Preview) computes every page, which < and >
%   then only draw.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Force (1,1) logical = false
    opts.AllPages (1,1) logical = false
end
if ismember(obj.PreviewState, ["computing" "drawing"])
    obj.PreviewRedo = true;
    return
end
L = obj.PreviewLabel;
if obj.SelectedPlot < 1 || obj.SelectedPlot > numel(obj.Config.Plots)
    L.Text = "No plot selected.";
    obj.setPreviewState("idle");
    return
end
if isempty(obj.Runner) || obj.ActiveIdx < 1
    L.Text = "Scan and pick a dataset to preview.";
    obj.setPreviewState("idle");
    return
end
spec = obj.Config.plotFor(obj.SelectedPlot);
spec.enabled = true;
try
    src = obj.Runner.source(obj.ActiveIdx);
catch ME
    L.Text = "Cannot read the dataset: " + string(ME.message);
    obj.setPreviewState("failed");
    return
end
reason = plotSkipReason(src, spec);
if reason ~= ""
    clearPanel(obj, spec.id + " cannot be drawn for " + src.name + ": " + reason + ".");
    obj.setPreviewState("skipped");
    return
end
if ~opts.Force && ismember(spec.source, EphysAnalysisConfig.SignalSources)
    f = src.outputs.signalFile(spec.source);
    mb = 0;
    for x = f; d = dir(x); if ~isempty(d); mb = mb + d(1).bytes / 2^20; end; end
    if mb > obj.PreviewMaxMB
        clearPanel(obj, sprintf("The %s extract is %.0f MB (over %g MB): press Preview to read it.", spec.source, mb, obj.PreviewMaxMB));
        obj.PreviewSeconds = Inf;
        obj.setPreviewState("waiting");
        return
    end
end
L.Text = "Computing " + spec.id + " ...";
rn = obj.Runner;
rn.clearCancel();   % before the badge paints: a click on Cancel can come in while it does
obj.PreviewRedo = false;
obj.setPreviewState("computing", Message="Computing " + spec.id + " on " + src.name + " ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
polling = onCleanup(@() stopPolling(rn));
try
    page = max(obj.PreviewPage, 1);
    if opts.AllPages; page = 0; end
    R = rn.computePlot(src, spec, Page=page);
    rn.PollFcn = [];
    obj.PreviewResult = R;
    obj.PreviewPages = plotPageCount(R, spec);
    obj.PreviewPage = min(max(obj.PreviewPage, 1), obj.PreviewPages);
    L.Text = "Drawing " + spec.id + " ...";
    obj.setPreviewState("drawing", Message="Drawing " + spec.id + " ...");
    obj.Runner.renderPlotFigures(R, spec, Target=obj.PreviewPanel, Page=obj.PreviewPage, ...
        OnRemember=@(rules) obj.rememberAesthetics(spec.id, rules));
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end   % the app was closed while it computed
    obj.PreviewResult = [];
    if ME.identifier == "EphysAnalysisRunner:Cancelled"
        clearPanel(obj, spec.id + " was cancelled: press Preview to compute it.");
        obj.PreviewSeconds = Inf;
        obj.log(spec.id + " preview cancelled.");
        obj.setPreviewState("cancelled");
        return
    end
    clearPanel(obj, spec.id + " failed: " + string(ME.message));
    obj.PreviewSeconds = Inf;
    obj.log(spec.id + " preview failed: " + string(ME.message));
    obj.setPreviewState("failed");
    return
end
obj.PreviewSeconds = toc(t0);
obj.setPreviewState("drawn");
if obj.PreviewRedo; obj.setPreviewState("stale"); end
L.Text = sprintf("%s on %s (%.1f s); right-click the plot to change its colours, lines and fonts", ...
    spec.id, src.name, obj.PreviewSeconds);
if obj.PreviewSeconds >= obj.AutoPreviewSeconds && obj.AutoPreviewCheckBox.Value
    L.Text = L.Text + ": slow, so edits wait for Preview";
end
syncPages(obj);
end


function stopPolling(rn)
if isvalid(rn); rn.PollFcn = []; end
end


function clearPanel(obj, msg)
delete(obj.PreviewPanel.Children);
g = uigridlayout(obj.PreviewPanel, [1 1]);
uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
obj.PreviewLabel.Text = msg;
obj.PreviewPages = 1;
obj.PreviewPage = 1;
syncPages(obj);
end


function syncPages(obj)
n = obj.PreviewPages;
p = obj.PreviewPage;
obj.PrevPageButton.Enable = matlab.lang.OnOffSwitchState(p > 1);
obj.NextPageButton.Enable = matlab.lang.OnOffSwitchState(p < n);
if n > 1
    obj.PageLabel.Text = sprintf("page %d of %d", p, n);
else
    obj.PageLabel.Text = "";
end
end
