function ok = gotoFigureSetting(obj, id, role, panel)
%gotoFigureSetting  Go to the figure editor's setting that controls a part of a drawn figure, and focus its control.
%   OK = gotoFigureSetting(OBJ, ID, ROLE, PANEL) is the preview's
%   right-click "Go to setting". It shows the Figures tab, picks figure ID
%   and its panel PANEL (an id; "" for the figure's own parts: the title),
%   then goes to the first of figureRoleSettings(ROLE) that the panel
%   shows: its supersection and section open, the editor scrolls to the
%   row, its control takes the keyboard focus (the exact control: the
%   "Error" box of the Show row, say) and its label is highlighted for a
%   moment (gotoFigureRow). A part with no setting of its own goes to the
%   Appearance section. When no candidate is shown for the panel, the
%   status bar says why for the first (figureRowReason). OK is true when
%   it went to a setting.
%
%   See also figureRoleSettings, gotoFigureRow, PlotAesthetics.enableEditing.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    role (1,1) string
    panel (1,1) string = ""
end
ok = false;
k = obj.Config.figureIndex(followedFigureId(obj, id));
if k < 1
    obj.setStatus("Figure " + id + " is gone.");
    return
end
try figure(obj.Fig); catch; end   % a part of a window of its own: the app comes to the front
if obj.Tabs.SelectedTab ~= obj.TabFigures; obj.selectTab(obj.TabFigures); end
if k ~= obj.SelectedFigure; obj.onFigureSelected(k); end
if panel ~= ""
    p = find([obj.Config.Figures(k).panels.id] == panel, 1);
    if ~isempty(p) && p ~= obj.SelectedPanel; obj.onPanelSelected(p); end
end
X = obj.FigureSearchIndex;
first = 0;
for key = figureRoleSettings(role)
    i = entryOf(X, key);
    if i == 0; continue; end
    if first == 0; first = i; end
    if obj.gotoFigureRow(i)
        E = obj.FigureEditor;
        if isfield(E, key) && isscalar(E.(key)) && isgraphics(E.(key))
            try focus(E.(key)); catch; end   % the row's own control, not the first of its row
        end
        ok = true;
        return
    end
end
if first > 0
    obj.gotoFigureRow(first);   % none is shown for this panel: the status bar says why for the likeliest
end
end


function i = entryOf(X, key)
%entryOf  The index in the search index of the row with formRow key KEY, or of section "@name"'s header; 0 when none.
i = 0;
if startsWith(key, "@")
    i = find([X.Section] == extractAfter(key, 1) & [X.Row] == 0, 1);
else
    i = find(cellfun(@(c) any(c == key), {X.Keys}), 1);
end
if isempty(i); i = 0; end
end
