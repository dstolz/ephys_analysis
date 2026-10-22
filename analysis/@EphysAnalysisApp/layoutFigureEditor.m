function layoutFigureEditor(obj)
%layoutFigureEditor  Pack the figure editor's shown sections, under their supersections' headers, to the top and size them.
%   Each section packs its shown rows and takes its height (formLayout):
%   the header alone when collapsed, none when hidden. The always-open
%   section (Id, Title, ...) comes first; then each supersection
%   (FigureSupers): its header, 30 px while a figure is selected, then its
%   sections, none of them when it is collapsed. A header reads
%   "▼  FIGURE   (Alt+1)", "►" when collapsed; the Panel supersection's
%   names the selected panel ("PANEL  psth_1 (PSTH)") or says none is
%   picked. What shows takes the editor's first rows, what does not
%   zero-height rows below it (out of sight, and skipped by Tab), and a
%   last row the space left (the editor scrolls when they need more).
%   syncFigureEditor decides what shows; onFigureSectionToggled and
%   onFigureSuperToggled what is collapsed. Only what changed is set (a
%   row's Layout.Row costs as much when it is the same: formLayout).
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
    t = superText(obj, U(u), any(h(in) > 0) || ~U(u).Expanded);
    if ~isequal(string(U(u).Header.Text), t); U(u).Header.Text = t; end
    items = [items {U(u).Header} {S(in).Grid}]; %#ok<AGROW>
    hs = [hs 30 * has h(in)]; %#ok<AGROW>
end
on = hs > 0;
order = [find(on) find(~on)];
for i = 1:numel(order)
    if ~isequal(items{order(i)}.Layout.Row, i); items{order(i)}.Layout.Row = i; end
end
for u = 1:numel(U)
    U(u).Header.Visible = matlab.lang.OnOffSwitchState(has);
end
rh = [num2cell([hs(on) zeros(1, nnz(~on))]) {'1x'}];
if ~isequal(obj.FigureEditorGrid.RowHeight, rh); obj.FigureEditorGrid.RowHeight = rh; end
obj.FigureSections = S;
i = find(names == "arrangement", 1);
if ~isempty(i) && ~(h(i) > 0 && S(i).Expanded) && isfield(obj.FigureEditor, 'schematicPanel')
    obj.FigureEditor.schematicPanel.UserData = false;   % its axes is made afresh when it shows (drawFigureSchematic)
end
end


function t = superText(obj, U, shows)
%superText  A supersection header's text: its arrow, its title in capitals, the selected panel (Panel) and its key.
arrow = "▼";
if ~U.Expanded; arrow = "►"; end
t = arrow + "  " + upper(U.Title);
if U.Name == "panel"
    k = obj.SelectedFigure;
    j = obj.SelectedPanel;
    if k >= 1 && k <= numel(obj.Config.Figures) && j >= 1 && j <= numel(obj.Config.Figures(k).panels)
        p = obj.Config.Figures(k).panels(j);
        PT = EphysAnalysisConfig.panelTypes();
        lbl = PT.Label(PT.Type == p.type);
        if isempty(lbl); lbl = p.type; end
        t = t + "   " + p.id + " (" + lbl + ")";
    elseif ~shows
        t = t + "   (none picked: add a panel, or click one in the schematic)";
    end
end
if ismac; chord = "Option+" + U.Key; else; chord = "Alt+" + U.Key; end
t = t + "      (" + chord + ")";
end
