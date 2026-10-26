function refreshFigurePreview(obj, opts)
%refreshFigurePreview  Compute and draw the selected figure for the observation picked, on the active dataset.
%   Goes through the runner and the scriptable core: Config.figureFor,
%   figureSkipReason, EphysAnalysisRunner.computeFigure for the one
%   observation picked over the preview (FigureObservations), then
%   renderFigure into the preview panel -- so only that unit's spikes or
%   that channel's column are read, and an edit redraws quickly. A figure
%   the dataset cannot draw says why (a layer it cannot draw says so in
%   its panel); a signal extract a layer reads above PreviewMaxMB is only
%   read when Force is set (the Preview button). The time taken decides
%   whether edits redraw it (autoFigurePreview, under AutoPreviewSeconds);
%   the first figure drawn after the app starts is not counted, since it
%   also loads the graphics. A right-click on the preview opens the
%   aesthetics editor; what it remembers for the figure comes back through
%   rememberFigureAesthetics, an axis label's own text or side (its menu)
%   through onFigureAxisEdited. The selected panel is outlined in the
%   preview (markFigurePanel), and a Ctrl+Click on a panel selects it and
%   goes to its section of the editor (onFigurePanelClicked). The
%   preview is the shape of the figure's export page (fitFigureViews:
%   Size in the editor, else the Export tab's), drawn as exported and
%   scaled to it (previewScale: every font, line and marker). The badge
%   (setFigurePreviewState) says Computing, then Drawing, with a card over the old drawing whose Cancel
%   (onCancelFigurePreview) stops the compute at its next checkpoint (the
%   runner polls: Runner.PollFcn); edits made meanwhile leave it Out of
%   date. Nothing is computed while a run goes (the runner is busy).
%   A session figure (sessions.enabled) is drawn across the ticked (or
%   listed) datasets instead: EphysAnalysisRunner.computeSessionFigure for
%   the matched observation picked (refreshFigureObservations lists
%   figureSessionObservations), every figure it makes kept in
%   FigureSessionResults; the "Figure:" drop-down under the preview
%   (FigureSessionDropDown, shown when there are several: one per subject
%   or trial group) picks the one drawn, and the status line says how many
%   sessions were merged and skipped. The active dataset is not used. A
%   panel with Y limits "Shared by batch" (yLimMode "batch") is drawn on its
%   own range, the one observation not knowing the run's: the status line
%   says the run shares it. Redraw
%   (onFigureSessionPicked) draws another of the kept figures without
%   computing.
%   It draws into the selected figure's own container (FigurePreviewPanel,
%   syncFigureView: shown first when it is not yet), and keeps the key it
%   drew with (FigurePreviewDrawn: figureViewKey, so the tree and a switch
%   back can tell whether the drawing is still current). The selection can
%   move while it computes (the tree, a favorite, Undo): the figure that
%   computes stays shown until it is drawn into its own container, then the
%   selected figure's is shown (syncFigureView) and drawn when out of date
%   (previewFigureView).
arguments
    obj (1,1) EphysAnalysisApp
    opts.Force (1,1) logical = false
    opts.Redraw (1,1) logical = false
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])
    obj.FigurePreviewRedo = true;
    return
end
obj.syncFigureView();   % the selected figure's container (it already shows, but for a selection made without the tree)
obj.fitFigureViews();   % in the shape of its export page, which the drawing is scaled to (previewScale)
previewNow(obj, opts);
if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end   % the app was closed while it computed
if obj.syncFigureView(); previewFigureView(obj); end   % the selection moved meanwhile: its figure now
end


function previewNow(obj, opts)
%previewNow  The preview of the selected figure, in its container (refreshFigurePreview's work).
L = obj.FigurePreviewLabel;
if obj.Running
    L.Text = "A run is going: preview the figure when it is done.";
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.FigurePreviewResult = [];
    clearPanel(obj, "No figure: press Add under the list, then pick its first panel.");
    obj.setFigurePreviewState("idle");
    showSessionPicker(obj, []);
    return
end
if obj.Config.Figures(k).sessions.enabled && ~isempty(obj.Runner)
    if opts.Redraw
        K = obj.FigureSessionResults;
        if ~(isstruct(K) && isfield(K, 'res') && K.spec.id == obj.Config.Figures(k).id)   % kept for another figure: not current
            clearSessionFigurePreview(obj);
            if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
            return
        end
        drawSessionEntry(obj, 0);
    else
        sessionPreview(obj);
    end
    return
end
showSessionPicker(obj, []);
if isempty(obj.Runner) || obj.ActiveIdx < 1
    obj.FigurePreviewResult = [];
    clearPanel(obj, "Scan and pick a dataset to preview.");
    obj.setFigurePreviewState("idle");
    return
end
spec = obj.Config.figureFor(k);
spec.enabled = true;   % a figure that is off is still previewed
try
    src = obj.Runner.source(obj.ActiveIdx);
catch ME
    clearPanel(obj, "Cannot read the dataset: " + string(ME.message));
    obj.setFigurePreviewState("failed");
    return
end
reason = figureSkipReason(src, spec);
if reason ~= ""
    obj.FigurePreviewResult = [];
    clearPanel(obj, spec.id + " cannot be drawn for " + src.name + ": " + reason + ".");
    obj.setFigurePreviewState("skipped");
    return
end
obj.refreshFigureObservations();
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if ~istable(T) || height(T) == 0 || ~isnumeric(i) || i < 1 || i > height(T)
    obj.FigurePreviewResult = [];
    U = obj.FigureObservationDropDown.UserData;
    if isstruct(U) && isfield(U, 'error') && U.error ~= ""   % the list could not be made: say why
        clearPanel(obj, spec.id + " on " + src.name + ": " + U.error);
        obj.setFigurePreviewState("failed");
        return
    end
    clearPanel(obj, spec.id + " has nothing to draw on " + src.name + ": no " + spec.observe.kind + ...
        " passes the Observations section's filter.");
    obj.setFigurePreviewState("skipped");
    return
end
obs = T(i, :);
drawnKey = figureViewKey(obj, k);   % what it is drawn from (FigurePreviewDrawn once drawn)
if ~opts.Force
    mb = signalMB(spec, src);
    if mb > obj.PreviewMaxMB
        clearPanel(obj, sprintf("A layer reads %.0f MB of signal (over %g MB): press Preview to read it.", mb, obj.PreviewMaxMB));
        obj.FigurePreviewSeconds = Inf;
        obj.setFigurePreviewState("waiting");
        return
    end
end
what = spec.id + " (" + obs.label + ")";
L.Text = "Computing " + what + " ...";
rn = obj.Runner;
rn.clearCancel();   % before the badge paints: a click on Cancel can come in while it does
obj.FigurePreviewRedo = false;
obj.setFigurePreviewState("computing", Message="Computing " + what + " on " + src.name + " ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
polling = onCleanup(@() stopPolling(rn));
try
    F = rn.computeFigure(src, spec, Observation=obs, Reuse=true);   % what an earlier preview computed on the same data is taken again (a look-only edit computes nothing)
    rn.PollFcn = [];
    obj.FigurePreviewResult = F;
    L.Text = "Drawing " + what + " ...";
    obj.setFigurePreviewState("drawing", Message="Drawing " + what + " ...");
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl) obj.onFigurePanelClicked(spec.id, panel, ctrl, false), ...
        Reuse=true);   % only the panels that changed drawn again
    obj.markFigurePanel();   % the selected panel outlined
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end   % the app was closed while it computed
    obj.FigurePreviewResult = [];
    obj.FigurePreviewSeconds = Inf;
    switch string(ME.identifier)
        case "EphysAnalysisRunner:Canceled"
            clearPanel(obj, spec.id + " was canceled: press Preview to compute it.");
            obj.log(spec.id + " figure preview canceled.");
            obj.setFigurePreviewState("canceled");
        case {"EphysAnalysisRunner:FigureSkipped" "EphysAnalysisRunner:NoObservation"}
            clearPanel(obj, string(ME.message));
            obj.setFigurePreviewState("skipped");
        otherwise
            clearPanel(obj, spec.id + " failed: " + string(ME.message));
            obj.log(spec.id + " figure preview failed: " + string(ME.message));
            obj.setFigurePreviewState("failed");
    end
    return
end
secs = toc(t0);
obj.FigurePreviewSeconds = secs;
if ~obj.FigurePreviewWarm   % the first figure drawn also loads the graphics: its time does not stop auto-preview
    obj.FigurePreviewSeconds = 0;
    obj.FigurePreviewWarm = true;
end
obj.FigurePreviewDrawn = drawnKey;
obj.setFigurePreviewState("drawn");
if obj.FigurePreviewRedo; obj.setFigurePreviewState("stale"); end
L.Text = sprintf("%s, %s on %s (%.1f s); right-click to change colors, lines and fonts", spec.id, obs.label, src.name, secs);
if obj.FigurePreviewSeconds >= obj.FigureAutoPreviewSeconds && obj.FigureAutoCheckBox.Value
    L.Text = L.Text + ": slow, so edits wait for Preview";
end
L.Text = L.Text + batchNote(spec);
end


function sessionPreview(obj)
%sessionPreview  A session figure: the observation picked computed on every session and merged, then drawn.
L = obj.FigurePreviewLabel;
spec = obj.Config.figureFor(obj.SelectedFigure);
spec.enabled = true;   % a figure that is off is still previewed
obj.refreshFigureObservations();
T = obj.FigureObservations;
dd = obj.FigureObservationDropDown;
i = dd.Value;
if ~istable(T) || height(T) == 0 || ~isnumeric(i) || i < 1 || i > height(T)
    obj.FigurePreviewResult = [];
    obj.FigureSessionResults = [];
    showSessionPicker(obj, []);
    U = dd.UserData;
    if isstruct(U) && isfield(U, 'error') && U.error ~= ""
        clearPanel(obj, spec.id + " across sessions: " + U.error);
        obj.setFigurePreviewState("failed");
        return
    end
    clearPanel(obj, spec.id + " has nothing to draw across the sessions: no " + spec.observe.kind + ...
        " is matched in enough of them (Sessions: Min. sessions).");
    obj.setFigurePreviewState("skipped");
    return
end
obs = T(i, :);
drawnKey = figureViewKey(obj, obj.SelectedFigure);
what = spec.id + " (" + obs.label + ")";
L.Text = "Computing " + what + " across " + obs.nSessions + " session(s) ...";
rn = obj.Runner;
rn.clearCancel();
obj.FigurePreviewRedo = false;
obj.setFigurePreviewState("computing", Message="Computing " + what + " across " + obs.nSessions + " session(s) ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
polling = onCleanup(@() stopPolling(rn));
try
    res = rn.computeSessionFigure(spec, obj.tickedDatasetIndices(), Observation=obs);
    rn.PollFcn = [];
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end
    obj.FigurePreviewResult = [];
    obj.FigureSessionResults = [];
    showSessionPicker(obj, []);
    obj.FigurePreviewSeconds = Inf;
    switch string(ME.identifier)
        case "EphysAnalysisRunner:Canceled"
            clearPanel(obj, spec.id + " was canceled: press Preview to compute it.");
            obj.setFigurePreviewState("canceled");
        case {"EphysAnalysisRunner:FigureSkipped" "EphysAnalysisRunner:NoObservation"}
            clearPanel(obj, string(ME.message));
            obj.setFigurePreviewState("skipped");
        otherwise
            clearPanel(obj, spec.id + " across sessions failed: " + string(ME.message));
            obj.log(spec.id + " session figure preview failed: " + string(ME.message));
            obj.setFigurePreviewState("failed");
    end
    return
end
clear polling
labels = string({res.label});
j = 1;
if isstruct(obj.FigureSessionResults) && isfield(obj.FigureSessionResults, 'label')   % keep the figure picked, by its label
    q = find(labels == obj.FigureSessionResults.label, 1);
    if ~isempty(q); j = q; end
end
obj.FigureSessionResults = struct('res', res, 'spec', spec, 'what', what, 'label', labels(j), 'seconds', toc(t0), 'key', drawnKey);
showSessionPicker(obj, labels, j);
drawSessionEntry(obj, toc(t0));
end


function drawSessionEntry(obj, secs)
%drawSessionEntry  Draw the kept session figure the "Figure:" drop-down picks (FigureSessionResults); SECS: the compute's time (0 = a redraw).
K = obj.FigureSessionResults;
L = obj.FigurePreviewLabel;
dd = obj.FigureSessionDropDown;
j = 1;
if strcmp(dd.Visible, 'on') && isnumeric(dd.Value) && dd.Value >= 1 && dd.Value <= numel(K.res); j = dd.Value; end
e = K.res(j);
obj.FigureSessionResults.label = e.label;
spec = K.spec;
if e.status ~= "done"
    obj.FigurePreviewResult = [];
    clearPanel(obj, spec.id + " (" + e.label + ") is not drawn across the sessions: " + e.message);
    obj.setFigurePreviewState("skipped");
    return
end
F = e.F;
obj.FigurePreviewResult = F;
L.Text = "Drawing " + K.what + " ...";
obj.setFigurePreviewState("drawing", Message="Drawing " + K.what + " ...");
try
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl) obj.onFigurePanelClicked(spec.id, panel, ctrl, false));
    obj.markFigurePanel();
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end
    obj.FigurePreviewResult = [];
    clearPanel(obj, spec.id + " failed: " + string(ME.message));
    obj.log(spec.id + " session figure preview failed: " + string(ME.message));
    obj.setFigurePreviewState("failed");
    return
end
if secs > 0; obj.FigurePreviewSeconds = secs; end
obj.FigurePreviewDrawn = K.key;
obj.setFigurePreviewState("drawn");
if obj.FigurePreviewRedo; obj.setFigurePreviewState("stale"); end
S = F.sessions;
nDone = nnz(S.status == "done");
nOther = height(S) - nDone;
txt = sprintf("%s, %s across sessions: %d merged", spec.id, string(F.observation.label), nDone);
if nOther > 0
    why = S.label(S.status ~= "done") + ": " + S.message(S.status ~= "done");
    txt = txt + sprintf(", %d skipped (%s)", nOther, strjoin(why, "; "));
end
if numel(K.res) > 1; txt = txt + " — " + e.label; end
if secs > 0; txt = txt + sprintf(" (%.1f s)", secs); end
L.Text = txt + "; right-click to change colors, lines and fonts" + batchNote(spec);
end


function t = batchNote(spec)
%batchNote  The status line's word on panels whose y range a run shares (yLimMode "batch"): the preview draws its own.
t = "";
ids = figureBatchPanels(spec);
if isempty(ids); return; end
t = "; Y limits of " + strjoin(ids, ", ") + " are shared by every observation when generated (here this one's own range)";
end


function mb = signalMB(spec, src)
%signalMB  The size of the signal extracts the figure's enabled layers read, MB.
srcs = strings(1, 0);
for p = spec.panels
    if isempty(p.layers); continue; end
    on = [p.layers.enabled];
    srcs = [srcs p.layers(on).source]; %#ok<AGROW>
end
if isfield(spec, 'observe'); srcs(end+1) = spec.observe.data; end   % an observed signal (kept below)
srcs = unique(srcs(ismember(srcs, EphysAnalysisConfig.SignalSources)));
mb = 0;
for s = srcs
    try
        f = src.outputs.signalFile(s);
    catch
        continue
    end
    for x = reshape(string(f), 1, [])
        d = dir(x);
        if ~isempty(d); mb = mb + d(1).bytes / 2^20; end
    end
end
end


function stopPolling(rn)
if isvalid(rn); rn.PollFcn = []; end
end


function clearPanel(obj, msg)
%clearPanel  The preview panel empty but for MSG, which the status line under it says too.
delete(obj.FigurePreviewPanel.Children);
g = uigridlayout(obj.FigurePreviewPanel, [1 1]);
uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
obj.FigurePreviewLabel.Text = msg;
end
