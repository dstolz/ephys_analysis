function onFigureSelected(obj, k)
%onFigureSelected  Edit figure K (its edits so far are already in the config) and show its preview.
%   The editor comes back as figure K left it (saveFigureEditorState when
%   it was left, restoreFigureEditorState, scrollFigureEditor): its
%   sections open or collapsed, its scroll, its panel and layer; a figure
%   not shown before gets its first panel and layer, the sections as they
%   are. The picker lists its observations (the one it last showed, when
%   still there): the list it kept when its key is the same
%   (takeFigurePicker), else made again. The tree selects it and the preview shows its own
%   container (refreshFigureList, syncFigureView): the drawing it kept
%   when it is still current, else it is drawn again (Auto) or marked Out
%   of date (previewFigureView). While another preview computes, the
%   editor follows at once and the preview when that one is done
%   (refreshFigurePreview).
if isempty(k) || ~isnumeric(k); return; end
k = k(1);
if k < 1 || k > numel(obj.Config.Figures); return; end
other = k ~= obj.SelectedFigure;
S = [];
if other
    saveFigureEditorState(obj);   % the editor as the figure left had it
    obj.SelectedFigure = k;
    obj.SelectedPanel = 1;
    obj.SelectedLayer = 1;
    S = restoreFigureEditorState(obj, obj.Config.Figures(k).id);   % as figure K left it, when it was shown before
end
obj.refreshFigureList();   % its container shown (syncFigureView)
obj.applyFigureEditor();
scrollFigureEditor(obj, S);
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
if ~other; return; end
previewFigureView(obj);   % its kept drawing, or drawn again when out of date
end
