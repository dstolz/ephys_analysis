function ok = quickFigurePreview(obj, opts)
%quickFigurePreview  Draw the selected figure's preview again from what the runner holds, with no busy card: nothing computed, only the panels that changed drawn.
%   OK = quickFigurePreview(OBJ) is tried before a preview with the busy
%   card (refreshFigurePreview) after an edit: by commitFigureEdit (a
%   panel removed or reordered, a layer edited) and autoFigurePreview (Undo
%   and Redo, the cached edits of onConfigChanged). The figure is computed
%   for the observation picked from the runner's cache alone
%   (EphysAnalysisRunner.computeFigure CacheOnly: no checkpoint polls,
%   nothing read) and drawn with Reuse (renderFigure: the panels that would
%   be drawn alike kept by id, the rest drawn, the figure dressed again
%   over all of them). Then the preview's tail as refreshFigurePreview's
%   (finishPreview: FigurePreviewResult, the time, FigurePreviewDrawn, the
%   badge Drawn, the status line), the selected panel outlined
%   (markFigurePanel) and a paint that runs no callback (drawnow
%   nocallbacks).
%   KeptOnly=true draws only when every panel is kept (renderFigure
%   KeptOnly): commitFigureEdit's settle after a panel removed or
%   reordered when the Auto slider's limit would not redraw the figure.
%   The time is kept (keepCost, FigurePreviewSeconds) only when a panel
%   was drawn: a drawing that kept every panel took next to no time, which
%   would make the next edit that draws one look free.
%   OK is false, and nothing is changed, when a run goes (Running), there is
%   no runner or active dataset, the selected figure is a session or probe
%   figure, the preview does not show it laid out (previewShowsFigure:
%   drawn or out of date, another figure, none), a preview computes or
%   draws already, the dataset cannot draw it (figureSkipReason), no
%   observation is picked, the runner's cache lacks a step
%   (figureCompute:CacheMiss) or the compute fails, or renderFigure draws
%   nothing (KeptOnly) or fails: the caller previews as before (with the
%   busy card) or marks the preview out of date.
%   While it runs, the preview's state is "drawing" without its card or
%   badge (so a callback run meanwhile, a Preview press, waits:
%   refreshFigurePreview's FigurePreviewRedo) and Applying is set (no
%   editor callback reads the editor back); both are restored after.
%
%   See also commitFigureEdit, autoFigurePreview, refreshFigurePreview, renderFigure.
arguments
    obj (1,1) EphysFigGenApp
    opts.KeptOnly (1,1) logical = false
end
ok = false;
k = obj.SelectedFigure;
rn = obj.Runner;
if obj.Running || isempty(rn) || obj.ActiveIdx < 1 || k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
if fig.sessions.enabled || fig.probe.enabled || ismember(obj.FigurePreviewState, ["computing" "drawing"]) || ~previewShowsFigure(obj)
    return
end
spec = obj.Config.figureFor(k);
spec.enabled = true;   % a figure that is off is still previewed
try
    src = rn.source(obj.ActiveIdx);
catch
    return
end
if figureSkipReason(src, spec) ~= ""; return; end
state0 = obj.FigurePreviewState;
wasApplying = obj.Applying;
obj.FigurePreviewState = "drawing";   % busy, without the card or the badge: a callback run meanwhile waits
obj.Applying = true;
guard = onCleanup(@() release(obj, state0, wasApplying)); %#ok<NASGU>
obj.refreshFigureObservations();   % (a figure renamed or its data followed: the list it is drawn for)
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if ~istable(T) || height(T) == 0 || ~isnumeric(i) || ~isscalar(i) || i < 1 || i > height(T); return; end
obs = T(i, :);
drawnKey = figureViewKey(obj, k);
dataKey = previewDataKey(obj, k);
obj.FigurePreviewRedo = false;
obj.fitFigureViews();   % (in the shape of its export page, as refreshFigurePreview draws it)
t0 = tic;
rn.PollFcn = [];   % (CacheOnly polls nothing)
try
    F = rn.computeFigure(src, spec, Observation=obs, Reuse=true, CacheOnly=true);
catch
    return   % a step not in the cache (figureCompute:CacheMiss), or a failure the busy preview reports
end
secsCompute = toc(t0);
try
    [~, how] = renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift), ...
        Reuse=true, KeptOnly=opts.KeptOnly);
catch ME
    obj.log(spec.id + ": the preview could not be drawn from what was computed, so it is computed again: " + string(ME.message));
    return
end
if how == ""; return; end   % KeptOnly: a panel to draw
obj.FigurePreviewResult = F;
finishPreview(obj, spec, obs, src, drawnKey, dataKey, secsCompute, toc(t0), Timed=how == "drawn");
obj.markFigurePanel();   % the selected panel outlined (once the state is no longer "drawing")
drawnow nocallbacks
ok = true;
end


function release(obj, state0, wasApplying)
%release  The busy state without its card back to what it was (unless the preview's tail set another), and Applying.
if ~isvalid(obj); return; end
if obj.FigurePreviewState == "drawing"; obj.FigurePreviewState = state0; end
obj.Applying = wasApplying;
end
