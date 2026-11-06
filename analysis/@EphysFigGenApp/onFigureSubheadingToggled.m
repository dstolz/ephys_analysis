function onFigureSubheadingToggled(obj, name, key, collapsed)
%onFigureSubheadingToggled  Fold away the rows under a collapsible sub-heading of the figure editor, or show them again.
%   onFigureSubheadingToggled(OBJ, NAME, KEY) flips sub-heading KEY of the
%   section NAME (formSubheading: KEY is the name it was made with, NAME the
%   section's, as for onFigureSectionToggled); onFigureSubheadingToggled(OBJ,
%   NAME, KEY, COLLAPSED) sets it (gotoFigureRow opens the group of the row it
%   goes to). The editor is laid out again: the rows under it get no height
%   and are hidden (Tab skips them), its arrow turns ("▸ Advanced" folded
%   away, "▾ Advanced" open). A sub-heading that is not collapsible, or a
%   name that is not one, does nothing. The state stays as left when another
%   figure is selected and between sessions (preference
%   FigureSubheadingsCollapsed, a list of "<section name>.<KEY>"; savePreferences,
%   loadPreferences).
arguments
    obj (1,1) EphysFigGenApp
    name (1,1) string
    key (1,1) string
    collapsed = []
end
i = find([obj.FigureSections.Name] == name, 1);
if isempty(i); return; end
S = obj.FigureSections(i);
k = find(S.Sub & S.SubCollapsible & S.SubKey == key, 1);
if isempty(k); return; end
if isempty(collapsed); collapsed = ~S.Collapsed(k); end
if logical(collapsed) == S.Collapsed(k); return; end
obj.FigureSections(i).Collapsed(k) = logical(collapsed);
obj.layoutFigureEditor();
end
