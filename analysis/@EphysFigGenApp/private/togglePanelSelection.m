function togglePanelSelection(obj, id)
%togglePanelSelection  Shift+click on panel ID of the selected figure: add it to the selected panels, or take it out.
%   togglePanelSelection(OBJ, ID), for a Shift+click on the panel in the
%   preview (onFigurePanelClicked) or on its box in Arrange
%   (onArrangeClicked):
%     not selected   it joins the selection as the primary (SelectedPanel:
%                    the panel whose values the editor's rows show), the
%                    one that was primary staying selected (FigurePanelExtra)
%     selected       it is taken out; the primary too, when others are
%                    selected (the one added last is the primary then);
%                    the primary alone stays selected
%   The editor then shows only the rows the selected panels share
%   (syncFigureEditor), the preview outlines each of them
%   (markFigurePanel; in Arrange their boxes are blue), and the status
%   bar names them. Nothing is recorded in the undo history: a selection
%   is not an edit.
%
%   See also selectedPanelIds, EphysFigGenApp.onFigurePanelClicked, EphysFigGenApp.onArrangeClicked.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
ids = [obj.Config.Figures(k).panels.id];
j = find(ids == id, 1);
if isempty(j); return; end
sel = selectedPanelIds(obj);
if isempty(sel)
    obj.FigurePanelExtra = strings(1, 0);
    obj.onPanelSelected(j);
    return
end
primary = sel(1);
extra = sel(2:end);
if id == primary
    if isempty(extra); return; end   % (the primary alone stays selected)
    next = extra(end);
    obj.FigurePanelExtra = extra(1:end-1);
    obj.onPanelSelected(find(ids == next, 1));
elseif any(extra == id)
    obj.FigurePanelExtra = extra(extra ~= id);
    obj.syncFigureEditor();   % the rows the panels left share; their outlines
else
    obj.FigurePanelExtra = [extra primary];
    obj.onPanelSelected(j);
end
sel = selectedPanelIds(obj);
if numel(sel) > 1
    obj.setStatus(sprintf("%d panels selected: %s. An edit goes to all of them; the editor shows the settings they " + ...
        "share. Shift+click a panel to add or remove it; Esc keeps %s alone.", numel(sel), strjoin(sel, ", "), sel(1)));
elseif ~isempty(sel)
    obj.setStatus("Selected " + sel(1) + ".");
end
end
