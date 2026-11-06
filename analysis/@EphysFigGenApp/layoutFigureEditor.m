function layoutFigureEditor(obj)
%layoutFigureEditor  Size the figure editor's sections, under their supersections' headers: what does not show gets no height.
%   Each section shows its rows and takes its height (formLayout):
%   the header alone when collapsed, none when hidden. The always-open
%   section (Id, Title, ...) comes first; then each supersection
%   (FigureSupers): its header, 30 px while a figure is selected, then its
%   sections, none of them when it is collapsed. A header reads
%   "▼  FIGURE   (Alt+1)", "►" when collapsed; the Panel supersection's
%   names the selected panel ("PANEL  psth_1 (PSTH)") or says none is
%   picked; with several selected (Shift+click) it counts and names them
%   ("PANEL  3 SELECTED: psth_1, psth_2, raster_1") on the selection's
%   blue (SelectionColor) instead of the headers' dark gray. Each header
%   and section keeps its row of the editor, in that order, with a 6 px
%   row under it for the gap; what does not show gets no height there (and
%   is hidden, so Tab skips it), and a last row takes the space left (the
%   editor scrolls when they need more). Nothing moves, so only the
%   editor's row heights change (formLayout).
%   syncFigureEditor decides what shows; onFigureSectionToggled and
%   onFigureSuperToggled what is collapsed. Only what changed is set.
S = obj.FigureSections;
U = obj.FigureSupers;
n = numel(S);
h = zeros(1, n);
for i = 1:n
    [S(i), h(i)] = formLayout(S(i));
end
names = [S.Name];
k = obj.SelectedFigure;
has = k >= 1 && k <= numel(obj.Config.Figures);
inSuper = false(1, n);
for u = 1:numel(U)
    inSuper = inSuper | ismember(names, U(u).Sections);
end
items = {S(~inSuper).Grid};   % the always-open section on top
hs = h(~inSuper);
for u = 1:numel(U)
    in = arrayfun(@(s) find(names == s, 1), U(u).Sections(ismember(U(u).Sections, names)));
    if ~U(u).Expanded
        for i = in
            S(i).Grid.Visible = "off";   % (formLayout shows it again when the supersection opens)
        end
        h(in) = 0;
    end
    [t, back] = superText(obj, U(u), any(h(in) > 0) || ~U(u).Expanded);
    if ~isequal(string(U(u).Header.Text), t); U(u).Header.Text = t; end
    if ~isequal(U(u).Header.BackgroundColor, back); U(u).Header.BackgroundColor = back; end
    items = [items {U(u).Header} {S(in).Grid}]; %#ok<AGROW>
    hs = [hs 30 * has h(in)]; %#ok<AGROW>
end
on = hs > 0;
for i = 1:numel(items)
    if ~isequal(items{i}.Layout.Row, 2 * i - 1); items{i}.Layout.Row = 2 * i - 1; end   % (its place for good: set once)
end
for u = 1:numel(U)
    U(u).Header.Visible = matlab.lang.OnOffSwitchState(has);
end
gap = 6 * on;   % the space under each shown item (the grid's RowSpacing is 0: buildFiguresTab)
gap(find(on, 1, 'last')) = 0;
rh = [num2cell(reshape([hs .* on; gap], 1, [])) {'1x'}];
if ~isequal(obj.FigureEditorGrid.RowHeight, rh); obj.FigureEditorGrid.RowHeight = rh; end
obj.FigureSections = S;
end


function [t, back] = superText(obj, U, shows)
%superText  A supersection header's text: its arrow, its title in capitals, the selected panel (Panel) and its key; BACK its color.
arrow = "▼";
if ~U.Expanded; arrow = "►"; end
t = arrow + "  " + upper(U.Title);
back = [0.21 0.26 0.35];   % (superHeader's)
if U.Name == "panel"
    k = obj.SelectedFigure;
    j = obj.SelectedPanel;
    sel = selectedPanelIds(obj);
    if numel(sel) > 1   % several selected (Shift+click): they show on the selection's blue
        t = t + sprintf("   %d SELECTED: ", numel(sel)) + strjoin(sel, ", ");
        back = EphysFigGenApp.SelectionColor;
    elseif k >= 1 && k <= numel(obj.Config.Figures) && j >= 1 && j <= numel(obj.Config.Figures(k).panels)
        p = obj.Config.Figures(k).panels(j);
        PT = EphysAnalysisConfig.panelTypes();
        lbl = PT.Label(PT.Type == p.type);
        if isempty(lbl); lbl = p.type; end
        t = t + "   " + p.id + " (" + lbl + ")";
    elseif ~shows
        t = t + "   (none picked: add a panel, or Ctrl+Click one in the preview)";
    end
end
if ismac; chord = "Option+" + U.Key; else; chord = "Alt+" + U.Key; end
t = t + "      (" + chord + ")";
end
