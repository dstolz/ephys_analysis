function trackFigureIds(obj, cfg)
%trackFigureIds  Note the figures CFG renames against obj.Config, so what refers to a figure by its id follows it.
%   trackFigureIds(OBJ, CFG) runs before the app takes CFG as its config
%   (onConfigChanged, commitFigureEdit, applyConfig for an edit). A
%   figure is renamed when the two configs hold as many figures and the
%   id at its place is new while its old id is gone from CFG: an
%   automatic id that followed an edit of the figure's panels or data
%   (EphysAnalysisConfig.autoFigureId), or an id typed. Then
%   - the observation the figure last showed (FigureObservation, by id)
%     moves to its new id, and so do its preview container (FigureViews,
%     FigureViewId: syncFigureView) and the editor state it left
%     (FigureEditorStates);
%   - FigureIdRenames maps the old id to the new one, for what holds a
%     figure's id while it lives: the right-click editor of the preview
%     and of a figure window (rememberFigureAesthetics) and the Spacing
%     window (figureSpacingDialog), which find the figure through
%     followedFigureId.
%   Adding, removing, duplicating and moving figures rename none (an
%   automatic id that still fits its figure is kept), so a change in the
%   number of figures is not looked at; the figure tree and the editor
%   hold the figure's index, not its id.
%
%   See also followedFigureId, EphysAnalysisConfig.normalizeFigures.
old = obj.Config.figureIds();
new = cfg.figureIds();
if numel(old) ~= numel(new); return; end
for k = find(old ~= new)
    if any(new == old(k)) || any(old == new(k)); continue; end   % moved, not renamed
    from = char(old(k));
    to = char(new(k));
    if isKey(obj.FigureIdRenames, to); remove(obj.FigureIdRenames, to); end   % a live id is its own (no cycle)
    obj.FigureIdRenames(from) = new(k);
    if isKey(obj.FigureObservation, from)
        obj.FigureObservation(to) = obj.FigureObservation(from);
        remove(obj.FigureObservation, from);
    end
    if isa(obj.FigureEditorStates, 'containers.Map') && isKey(obj.FigureEditorStates, from)
        obj.FigureEditorStates(to) = obj.FigureEditorStates(from);
        remove(obj.FigureEditorStates, from);
    end
    if ~isempty(obj.FigureViews)
        left = [obj.FigureViews.Id] == new(k) & new(k) ~= obj.FigureViewId;   % a container still kept for a figure gone with that id
        for v = find(left); delete(obj.FigureViews(v).Panel); end
        obj.FigureViews(left) = [];
        for v = find([obj.FigureViews.Id] == old(k))
            obj.FigureViews(v).Id = new(k);   % (its drawing is then out of date: the key holds the id)
        end
    end
    if obj.FigureViewId == old(k); obj.FigureViewId = new(k); end
end
end
