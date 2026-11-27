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
%   whether edits redraw it (autoFigurePreview, under the Auto slider's
%   limit): it is kept in two parts (FigurePreviewCost: computing, with
%   the data key computed, previewDataKey; drawing), from which
%   previewCost predicts the next edit's; the first figure drawn after the
%   app starts is not counted, since it also loads the graphics. A right-click on the preview opens the
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
%   runner polls: Runner.PollFcn, which lets callbacks run). Once drawn
%   it says Drawn only when the key it was computed for is still the
%   figure's (finishPreview: figureViewFresh), else Out of date: an edit
%   (with Auto on or off), another dataset or observation, a scan or a
%   Preview press made meanwhile (an edit undone meanwhile ends Drawn
%   unless it asked for a redraw: finishPreview). Nothing is computed or
%   drawn while a run goes (the runner is busy): the status line says so,
%   and a drawing that is no longer the figure as it is now (an edit, an
%   observation or a dataset picked meanwhile) says Out of date
%   (markStaleDrawing); another of a session figure's figures picked
%   ("Figure:", Redraw) is not taken: the drop-down goes back to the one
%   drawn (showSessionPick). A compute that throws, the three previews alike
%   (a local previewFailed), empties the preview but for why: Canceled,
%   Cannot draw (the runner's skip reason) or Failed (in the Log too);
%   except a Cancel (or an interrupt) while it still computes over a drawing
%   of the figure (drawingShown), which leaves that drawing, Out of date,
%   with the line saying it was canceled, as a signal extract over
%   PreviewMaxMB does (never Drawn: it is the figure as it was). Both wait
%   for Preview, also when the figure is shown again (FigurePreviewSeconds
%   Inf: previewFigureView).
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
%   A probe figure (probe.enabled) computes every tile on the active
%   dataset instead (EphysAnalysisRunner.computeProbeFigure, the card
%   saying "Computing tile 3/23 (<tile>) on <dataset> ...", Cancel at the
%   runner's checkpoints between the tiles) and draws them on one page
%   (renderFigure hands the result to renderProbeFigure; Reuse off); the
%   status line reads "<id> on <dataset>: 23 tiles, 3 left out (4.2 s);
%   ...". The Auto slider's rule (the seconds its parts took) applies as
%   for any figure.
%   It draws into the selected figure's own container (FigurePreviewPanel,
%   syncFigureView: shown first when it is not yet), and keeps the key it
%   drew with (FigurePreviewDrawn: figureViewKey, so the tree and a switch
%   back can tell whether the drawing is still current). The selection can
%   move while it computes (the tree, a favorite, Undo): the figure that
%   computes stays shown until it is drawn into its own container, then the
%   selected figure's is shown (syncFigureView) and drawn when out of date
%   (previewFigureView).
%   An interrupt (Ctrl+C) while it computes or draws leaves the preview as
%   Cancel does (Canceled, the panel empty but for why, press Preview; a
%   figure across sessions also forgets its kept figures): each preview --
%   a figure, a figure across sessions and the drawing of its kept figure
%   (drawSessionEntry: the Redraw path too), a probe figure -- makes an
%   onCleanup (previewInterrupted) before the state becomes computing or
%   drawing and keeps it to its end, after the tail. It stops the runner's
%   polls, and acts only when the state is still computing or drawing,
%   that is, when neither the tail (finishPreview) nor the catch
%   (previewFailed) nor a kept figure's skip set it: never after a
%   drawing that finished. Interrupted=ID (+ Sessions) runs that same
%   check by hand, as the cleanup does (the tests use it: they cannot press
%   Ctrl+C).
arguments
    obj (1,1) EphysFigGenApp
    opts.Force (1,1) logical = false
    opts.Redraw (1,1) logical = false
    opts.Interrupted (1,1) string = ""   % a figure id: what the cleanup of its preview does (tests)
    opts.Sessions (1,1) logical = false  % with Interrupted: the preview was of a figure across sessions
end
if opts.Interrupted ~= ""
    previewInterrupted(obj, obj.Runner, opts.Interrupted, opts.Sessions);
    return
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
if obj.Running   % nothing is computed or drawn: the drawing left is Out of date when it is not the figure as it is now
    if opts.Redraw   % another of a session figure's kept figures picked ("Figure:"): not drawn, so not taken
        showSessionPick(obj);   % the drop-down back on the one drawn, which stays the figure as it is
        L.Text = "A run is going: pick the figure under Figure: when it is done.";
    else
        L.Text = "A run is going: preview the figure when it is done.";
        markStaleDrawing(obj);   % an edit, an observation or a dataset picked meanwhile
    end
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.FigurePreviewResult = [];
    delete(obj.FigurePreviewPanel.Children);
    emptyStateCard(obj, obj.FigurePreviewPanel);   % what to do first, with Add one click away
    obj.FigurePreviewLabel.Text = "No figure: press Add under the list, then pick its first panel (or a saved figure, such as Raster over PSTH).";
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
    clearPanel(obj, "Cannot read the dataset: " + string(ME.message), "failed");
    obj.setFigurePreviewState("failed");
    return
end
reason = figureSkipReason(src, spec);
if reason ~= ""
    obj.FigurePreviewResult = [];
    what = figureSkipRemedy(reason);   % the reason in plain words, with what to do
    if what == ""; what = reason + "."; end
    clearPanel(obj, spec.id + " cannot be drawn for " + src.name + ". " + what, "skipped");
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
        clearPanel(obj, spec.id + " on " + src.name + ": " + U.error, "failed");
        obj.setFigurePreviewState("failed");
        return
    end
    if spec.probe.enabled
        clearPanel(obj, spec.id + " has nothing to draw on " + src.name + ": no " + spec.observe.kind + ...
            " has a site the Probe layout section lays out (" + string(obj.FigureEditor.obsCount.Text) + ")", "skipped");
    else
        clearPanel(obj, spec.id + " has nothing to draw on " + src.name + ": no " + spec.observe.kind + ...
            " passes the Observations section's filter.", "skipped");
    end
    obj.setFigurePreviewState("skipped");
    return
end
obs = T(i, :);
drawnKey = figureViewKey(obj, k);   % what it is drawn from (FigurePreviewDrawn once drawn)
obj.FigurePreviewTried = drawnKey;   % what this preview is for: a failure, a cancel or the size gate holds for this key alone (previewFigureView)
dataKey = previewDataKey(obj, k);   % what its data are computed from (FigurePreviewCost)
if ~opts.Force
    mb = signalMB(spec, src);
    if mb > obj.PreviewMaxMB
        msg = sprintf("A layer reads %.0f MB of signal (over %g MB): press Preview to read it.", mb, obj.PreviewMaxMB);
        obj.FigurePreviewSeconds = Inf;
        if drawingShown(obj)   % the last drawing stays, Out of date (never Drawn), the line says what waits
            obj.FigurePreviewLabel.Text = msg;
            obj.setFigurePreviewState("stale");
        else
            clearPanel(obj, msg);
            obj.setFigurePreviewState("waiting");
        end
        return
    end
end
if spec.probe.enabled   % every tile on one page
    probePreview(obj, spec, src, drawnKey, dataKey);
    return
end
what = spec.id + " (" + obs.label + ")";
L.Text = "Computing " + what + " ...";
rn = obj.Runner;
rn.clearCancel();   % before the badge paints: a click on Cancel can come in while it does
obj.FigurePreviewRedo = false;
keep = drawingShown(obj);   % a drawing in the panel before this compute: a cancel leaves it (Out of date)
interrupted = onCleanup(@() previewInterrupted(obj, rn, spec.id, false, keep)); %#ok<NASGU> to the end: the polls stop; an interrupt from here on is a cancel (the tail or the catch sets the state on every return)
obj.setFigurePreviewState("computing", Message="Computing " + what + " on " + src.name + " ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
try
    F = rn.computeFigure(src, spec, Observation=obs, Reuse=true);   % what an earlier preview computed on the same data is taken again (a look-only edit computes nothing)
    rn.PollFcn = [];
    secsCompute = toc(t0);
    obj.FigurePreviewResult = F;
    L.Text = "Drawing " + what + " ...";
    obj.setFigurePreviewState("drawing", Message="Drawing " + what + " ...");
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift), ...
        Reuse=true);   % only the panels that changed drawn again
    obj.markFigurePanel();   % the selected panel outlined
catch ME
    previewFailed(obj, spec, ME, Keep=keep);   % Canceled, Cannot draw or Failed, and why
    return
end
finishPreview(obj, spec, obs, src, drawnKey, dataKey, secsCompute, toc(t0));   % its time, key, badge (by key) and status line, as the others'
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
        clearPanel(obj, spec.id + " across sessions: " + U.error, "failed");
        obj.setFigurePreviewState("failed");
        return
    end
    clearPanel(obj, spec.id + " has nothing to draw across the sessions: no " + spec.observe.kind + ...
        " is matched in enough of them (Sessions: Min. sessions).", "skipped");
    obj.setFigurePreviewState("skipped");
    return
end
obs = T(i, :);
drawnKey = figureViewKey(obj, obj.SelectedFigure);
obj.FigurePreviewTried = drawnKey;   % (as above)
what = spec.id + " (" + obs.label + ")";
L.Text = "Computing " + what + " across " + obs.nSessions + " session(s) ...";
rn = obj.Runner;
rn.clearCancel();
obj.FigurePreviewRedo = false;
interrupted = onCleanup(@() previewInterrupted(obj, rn, spec.id, true)); %#ok<NASGU> to the end, over drawSessionEntry too: an interrupt is a cancel
obj.setFigurePreviewState("computing", Message="Computing " + what + " across " + obs.nSessions + " session(s) ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
try
    res = rn.computeSessionFigure(spec, obj.tickedDatasetIndices(), Observation=obs);
    rn.PollFcn = [];
catch ME
    previewFailed(obj, spec, ME, Sessions=true);   % (its kept figures and their picker go too)
    return
end
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
    clearPanel(obj, spec.id + " (" + e.label + ") is not drawn across the sessions: " + e.message, "skipped");
    obj.setFigurePreviewState("skipped");
    return
end
F = e.F;
obj.FigurePreviewResult = F;
L.Text = "Drawing " + K.what + " ...";
interrupted = onCleanup(@() previewInterrupted(obj, [], spec.id, true)); %#ok<NASGU> the Redraw path's only one (no polls): an interrupt while it draws is a cancel; nothing once drawn, skipped or failed
obj.setFigurePreviewState("drawing", Message="Drawing " + K.what + " ...");
try
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift));
    obj.markFigurePanel();
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end
    obj.FigurePreviewResult = [];
    clearPanel(obj, spec.id + " failed: " + string(ME.message), "failed");
    obj.log(spec.id + " session figure preview failed: " + string(ME.message));
    obj.setFigurePreviewState("failed");
    return
end
if secs > 0; obj.FigurePreviewSeconds = secs; end   % (its own time: a figure across sessions waits for Preview, so no parts are kept)
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
finishPreview(obj, spec, F.observation, [], K.key, [], 0, secs, Timed=false, Line=txt, Notes="batch");   % its key, badge (by key) and status line
end


function showSessionPick(obj)
%showSessionPick  The "Figure:" drop-down back on the kept session figure drawn (FigureSessionResults.label), as drawSessionEntry left it.
%   A pick made while a run goes draws nothing (previewNow), so it is not
%   taken: the drawing, its label (what Preview keeps through a compute,
%   Export preview and Export code name) and the drop-down stay one figure.
K = obj.FigureSessionResults;
dd = obj.FigureSessionDropDown;
if ~(isstruct(K) && isfield(K, 'res') && isfield(K, 'label')) || isempty(dd) || ~isvalid(dd); return; end
q = find(string({K.res.label}) == K.label, 1);
if ~isempty(q) && strcmp(dd.Visible, 'on') && numel(dd.Items) == numel(K.res); dd.Value = q; end   % (its ItemsData: 1:n, showSessionPicker)
end


function probePreview(obj, spec, src, drawnKey, dataKey)
%probePreview  A probe figure: every tile computed (the card counting them, Cancel between them), then drawn on one page.
%   EphysAnalysisRunner.computeProbeFigure, with what earlier previews
%   computed taken again (Reuse: the figure's epochs are one step every
%   tile shares; a look-only edit computes nothing), then renderFigure,
%   which hands the result (PF, kind "probeFigure") to renderProbeFigure:
%   drawn whole each time (Reuse off). The status line says how many tiles
%   and how many observations were left out. Timed in two parts as a
%   figure is (keepCost).
L = obj.FigurePreviewLabel;
what = spec.id + " on the probe";
L.Text = "Computing " + what + " ...";
rn = obj.Runner;
rn.clearCancel();   % before the badge paints: a click on Cancel can come in while it does
obj.FigurePreviewRedo = false;
keep = drawingShown(obj);   % (as previewNow's)
interrupted = onCleanup(@() previewInterrupted(obj, rn, spec.id, false, keep)); %#ok<NASGU> to the end, after the tail: an interrupt is a cancel, a drawing finished is left alone
obj.setFigurePreviewState("computing", Message="Computing the tiles of " + spec.id + " on " + src.name + " ...");
t0 = tic;
rn.PollFcn = @() drawnow("limitrate");
try
    PF =rn.computeProbeFigure(src, spec, Reuse=true, ProgressFcn=@(i, n, lab) obj.setFigurePreviewState("computing", ...
        Message=sprintf("Computing tile %d/%d (%s) on %s ...", i, n, lab, src.name)));
    rn.PollFcn = [];
    secsCompute = toc(t0);
    obj.FigurePreviewResult = PF;
    L.Text = "Drawing " + what + " ...";
    obj.setFigurePreviewState("drawing", Message="Drawing " + what + " (" + PF.nTiles + " tiles) ...");
    renderFigure(PF, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift), ...
        Reuse=false);   % drawn whole: its tiles are placed by arithmetic, not kept
    obj.markFigurePanel();   % (hides the outline: a probe figure's panels are many)
catch ME
    previewFailed(obj, spec, ME, Keep=keep);
    return
end
secs = toc(t0);
nLeft = 0;
if isfield(PF, 'left') && isstruct(PF.left)
    for f = ["noPosition" "filtered" "overSite" "overMax"]
        if isfield(PF.left, f); nLeft = nLeft + PF.left.(f); end
    end
end
txt = sprintf("%s on %s: %d tile%s", spec.id, src.name, PF.nTiles, repmat('s', 1, PF.nTiles ~= 1));
if nLeft > 0; txt = txt + sprintf(", %d left out", nLeft); end
finishPreview(obj, spec, [], src, drawnKey, dataKey, secsCompute, secs, Line=txt + sprintf(" (%.1f s)", secs), Notes="slow");   % its time in two parts, key, badge (by key), status line
end


function previewFailed(obj, spec, ME, opts)
%previewFailed  A preview's compute (or drawing) threw ME: the preview empty but for why, the badge Canceled, Cannot draw or Failed, the Log.
%   The catch of the three previews (a figure, a figure across sessions, a
%   probe figure). The result is dropped and the time made Inf (only
%   Preview draws it again: previewCost). EphysAnalysisRunner:Canceled
%   (Cancel on the card) is "canceled", a figure the dataset cannot draw
%   or with no observation (FigureSkipped, NoObservation) "skipped" with
%   the runner's words, anything else "failed" with its message, in the
%   Log too. Sessions=true (a figure across sessions): its kept figures
%   and their "Figure:" drop-down go too, a failure says "across
%   sessions" (the Log: "session figure preview failed"), and a cancel is
%   not logged. Keep=true (a drawing was in the panel before the compute
%   began: drawingShown) and the state still "computing" -- renderFigure had
%   not started, so the panel holds that drawing whole -- leaves a cancel
%   there, with its result and key: the badge says Out of date (never
%   Drawn: it is the figure as it was) and the line says what was canceled;
%   Preview computes it. A failure, a skip or a cancel while it draws empties
%   the panel as before. Nothing is done when the app was closed meanwhile.
arguments
    obj
    spec (1,1) struct
    ME (1,1) MException
    opts.Sessions (1,1) logical = false
    opts.Keep (1,1) logical = false
end
if ~isvalid(obj) || ~isvalid(obj.Fig); return; end   % the app was closed while it computed
canceled = string(ME.identifier) == "EphysAnalysisRunner:Canceled";
keep = opts.Keep && canceled && ~opts.Sessions && obj.FigurePreviewState == "computing";   % renderFigure had not begun: the drawing in the panel is the last one's, whole
if ~keep; obj.FigurePreviewResult = []; end
if opts.Sessions
    obj.FigureSessionResults = [];
    showSessionPicker(obj, []);
end
obj.FigurePreviewSeconds = Inf;
msg = string(ME.message);
switch string(ME.identifier)
    case "EphysAnalysisRunner:Canceled"
        msg = spec.id + " was canceled: press Preview to compute it.";
        if keep   % the last drawing stays, Out of date (the line says what was canceled), never Drawn
            obj.FigurePreviewLabel.Text = msg;
            obj.setFigurePreviewState("stale");
        else
            clearPanel(obj, msg);
            obj.setFigurePreviewState("canceled");
        end
        if ~opts.Sessions; obj.log(spec.id + " figure preview canceled."); end
    case {"EphysAnalysisRunner:FigureSkipped" "EphysAnalysisRunner:NoObservation"}
        clearPanel(obj, msg, "skipped");
        obj.setFigurePreviewState("skipped");
    otherwise
        if opts.Sessions
            clearPanel(obj, spec.id + " across sessions failed: " + msg, "failed");
            obj.log(spec.id + " session figure preview failed: " + msg);
        else
            clearPanel(obj, spec.id + " failed: " + msg, "failed");
            obj.log(spec.id + " figure preview failed: " + msg);
        end
        obj.setFigurePreviewState("failed");
end
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


function tf = drawingShown(obj)
%drawingShown  Whether the preview panel holds a drawing of the figure shown: Drawn or Out of date, with its result.
tf = ismember(obj.FigurePreviewState, ["drawn" "stale"]) && ~isempty(obj.FigurePreviewResult);
end


function stopPolling(rn)
if ~isempty(rn) && isvalid(rn); rn.PollFcn = []; end
end


function previewInterrupted(obj, rn, id, sessions, keep)
%previewInterrupted  A preview's cleanup: the runner's polls stop, and an interrupt (Ctrl+C) leaves the state as Cancel does.
%   The onCleanup of each preview (previewNow's figure, sessionPreview,
%   drawSessionEntry, which is the Redraw path's whole work, probePreview),
%   made before the state becomes "computing" (or "drawing") and kept to
%   the end of that function, so it runs once the function has returned,
%   after its tail. Every return sets the state the preview ends in --
%   finishPreview (Drawn, Out of date), previewFailed (Canceled, Cannot
%   draw, Failed), a kept session figure that is skipped or failed -- so
%   the state is still "computing" or "drawing" only when none of them ran:
%   an interrupt (or an error thrown outside the catch). Then, and only
%   then, the preview is Canceled (previewFailed's words; SESSIONS: a
%   figure across sessions, its kept figures forgotten too), so the badge,
%   the card and the guards that read "computing" or "drawing" (Run, Scan,
%   Test report, Generate, Export preview, Redraw All, the previews
%   themselves) are free again; after a success it changes nothing. RN [] =
%   no polls to stop (drawSessionEntry). quickFigurePreview has its own
%   (release: the state it had before, when its tail did not run). KEEP
%   (default false, the tests' Interrupted= check): a drawing was in the
%   panel before the compute, which an interrupt while it still computes
%   leaves there, Out of date (previewFailed Keep).
if nargin < 5; keep = false; end
stopPolling(rn);
if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])
    previewFailed(obj, struct('id', id), MException("EphysAnalysisRunner:Canceled", "The preview was interrupted."), Sessions=sessions, Keep=keep);
end
end


function clearPanel(obj, msg, broken)
%clearPanel  The preview panel empty but for MSG, which the status line under it says too.
%   clearPanel(OBJ, MSG, BROKEN) for a figure that cannot be drawn
%   (BROKEN "skipped") or failed ("failed"): MSG is not written in the
%   panel, where a long one ran past its edges, but held by a "cannot
%   draw" sign in its middle (icons/status/broken.svg, Tag
%   "previewBroken": a gray square struck through in red, as a panel of a
%   figure shows): its tooltip is MSG, a click shows MSG in a window over
%   the app (uialert), and a short line under it says so.
arguments
    obj
    msg (1,1) string
    broken (1,1) string {mustBeMember(broken, ["" "skipped" "failed"])} = ""
end
delete(obj.FigurePreviewPanel.Children);
obj.FigurePreviewLabel.Text = msg;
if broken == ""
    g = uigridlayout(obj.FigurePreviewPanel, [1 1]);
    uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
    return
end
head = "Cannot draw this figure";
icon = "warning";
if broken == "failed"; head = "The figure failed"; icon = "error"; end
g = uigridlayout(obj.FigurePreviewPanel, [4 1], "RowHeight", {'1x', 64, 'fit', '1x'}, "RowSpacing", 6);
im = uiimage(g, "ImageSource", fullfile(fileparts(fileparts(mfilename("fullpath"))), "icons", "status", "broken.svg"), ...
    "ScaleMethod", "fit", "Tag", "previewBroken", "Tooltip", msg, ...
    "ImageClickedFcn", @(~, ~) uialert(obj.Fig, msg, head, "Icon", icon));
im.Layout.Row = 2;
l = uilabel(g, "Text", [head; "Point at the sign, or click it, to see why."], "HorizontalAlignment", "center", ...
    "VerticalAlignment", "top", "FontColor", [0.4 0.4 0.4]);
l.Layout.Row = 3;
end
