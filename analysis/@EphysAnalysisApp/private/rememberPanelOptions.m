function rememberPanelOptions(obj, before, after)
%rememberPanelOptions  Remember the panel options an edit of the selected figure set, by panel type (obj.PanelOptions).
%   rememberPanelOptions(OBJ, BEFORE, AFTER), with the figures before and
%   after an edit (recordFigureEdit calls it for every edit of the
%   figures): each panel of the selected figure that was there before with
%   the same id and type gives every option whose value the edit changed
%   to obj.PanelOptions.(<type>).(<option>), the value as it is now (a
%   struct option, such as bins or the waveform inset, whole). A new panel
%   of that type starts from them (onNewPanel, rememberedPanelOptions);
%   the figures and the config never read them. They are a preference,
%   kept with the app's (savePreferences: PanelOptions), not the config.
%   Not remembered: an added, removed or retyped panel (its options are
%   the type's defaults or the old type's, not set by hand), an edit that
%   adds or removes figures, Undo and Redo (they record nothing), and the
%   options that name things of one dataset or one figure: rasterSortEvent
%   (an event line), a rasterSort of "event" (it needs that line), group
%   (a trial group of the figure's selection) and range (a stretch of one
%   recording). A rasterSort, param or seriesParam naming a trial
%   parameter is remembered and pre-filled only where the active dataset
%   has that parameter (rememberedPanelOptions).
%   Edit > Reset panel options to defaults forgets one type's, Edit >
%   Forget remembered panel options every type's.
%
%   See also rememberedPanelOptions, recordFigureEdit, EphysAnalysisApp.onResetPanelOptions,
%   EphysAnalysisApp.onForgetPanelOptions.
k = obj.SelectedFigure;
if numel(before) ~= numel(after) || k < 1 || k > numel(after); return; end
A = after(k).panels;
B = before(k).panels;
if isempty(A) || isempty(B); return; end
never = ["rasterSortEvent" "group" "range"];
M = obj.PanelOptions;
ids = [B.id];
for p = reshape(A, 1, [])
    q = B(ids == p.id);
    if ~isscalar(q) || q.type ~= p.type; continue; end
    for f = string(fieldnames(p.options)).'
        v = p.options.(f);
        if ismember(f, never) || (isfield(q.options, f) && isequaln(q.options.(f), v)); continue; end
        if f == "rasterSort" && isequal(string(v), "event"); continue; end
        if ~isfield(M, p.type); M.(p.type) = struct(); end
        M.(p.type).(f) = v;
    end
end
obj.PanelOptions = M;
end
