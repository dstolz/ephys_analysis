function ok = gotoFigureRow(obj, i, opts)
%gotoFigureRow  Go to a setting the figure editor's search found: open its supersection and section, scroll to it, focus its control, highlight it.
%   OK = gotoFigureRow(OBJ, I) goes to entry I of FigureSearchIndex
%   (figureSearchIndex): a supersection (gotoFigureSuper), a section or a
%   row. Its supersection and section open if collapsed, the editor
%   scrolls to it, its control (a section's header) takes the
%   keyboard focus and its label (else the control) is highlighted for a
%   moment; the status bar names it ("Panel > PSTH options > Bin (ms)").
%   A row the figure does not show stays where it is and the status bar
%   says why (figureRowReason: "Bin (ms) is an option of PSTH, heat map
%   and unit correlation panels: pick such a panel."), as does a section
%   the figure does not show (no panel picked; no panel aligned to
%   events). OK is true when it went there.
%
%   Focus=false leaves the keyboard focus where it is (a match picked in
%   the search list with the arrows: the editor shows it while the list
%   keeps the focus). Going there with the focus ends the search's hold on
%   Enter and the arrows (FigureSearchState).
arguments
    obj (1,1) EphysAnalysisApp
    i (1,1) double
    opts.Focus (1,1) logical = true
end
ok = false;
X = obj.FigureSearchIndex;
if i < 1 || i > numel(X); return; end
e = X(i);
if opts.Focus; obj.FigureSearchState = ""; end
where = figureSearchPath(obj, e);
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus(where + ": add a figure first, or pick one in the list.");
    return
end
if e.Row == -2   % a supersection
    if opts.Focus
        obj.gotoFigureSuper(e.Super);
    elseif ~obj.FigureSupers([obj.FigureSupers.Name] == e.Super).Expanded
        obj.onFigureSuperToggled(e.Super);
    end
    ok = true;
    return
end
s = find([obj.FigureSections.Name] == e.Section, 1);
S = obj.FigureSections(s);
fig = obj.Config.Figures(k);
hasPanel = obj.SelectedPanel >= 1 && obj.SelectedPanel <= numel(fig.panels);
type = "";
if hasPanel; type = fig.panels(obj.SelectedPanel).type; end
if ~(S.Visible && (isempty(S.Heights) || any(S.Shown)))   % the section is not shown for this figure
    obj.setStatus(sectionReason(e, S, fig, hasPanel));
    return
end
if e.Row > 0 && ~S.Shown(e.Row)
    obj.setStatus(figureRowReason(e.Label, e.Keys(1), type));
    return
end
u = find([obj.FigureSupers.Name] == S.Super, 1);
if ~isempty(u) && ~obj.FigureSupers(u).Expanded; obj.onFigureSuperToggled(S.Super); end
if ~obj.FigureSections(s).Expanded; obj.onFigureSectionToggled(e.Section); end
drawnow;   % the layout settles before the scroll
target = e.Target;
try
    scroll(obj.FigureEditorGrid, target);
catch
    try scroll(obj.FigureEditorGrid, S.Grid); catch; end
end
if opts.Focus
    try focus(target); catch; end
end
flash(obj, e.Flash);
how = "";
if isprop(target, 'Enable') && ~strcmp(target.Enable, 'on'); how = " (grayed out: another setting switches it off)"; end
obj.setStatus(where + how);
ok = true;
end


function why = sectionReason(e, S, fig, hasPanel)
%sectionReason  Why a section is not shown, in a sentence that names the setting looked for.
what = e.Label;
if e.Row == 0; what = "The " + S.Title + " section"; end
switch S.Name
    case {"panel" "palign" "layers" "options" "note" "overlays"}
        if isempty(fig.panels)
            why = what + " is a panel's: add a panel to the figure first (Arrangement).";
        elseif ~hasPanel
            why = what + " is a panel's: pick a panel in the schematic (Ctrl+] steps through them).";
        else
            why = what + " is not shown for this panel.";
        end
    case {"ref" "window" "selection"}
        why = what + " (" + S.Title + ") is not used: every panel of this figure is of a type not aligned to events.";
    otherwise
        why = what + " is not shown for this figure.";
end
end


function flash(obj, h)
%flash  Highlight H (a row's label, or its control) for a moment: a yellow ground, or bold text where it has no ground.
F = obj.FigureFlash;
if isstruct(F)   % the last highlight ends now
    restore(F);
    obj.FigureFlash = [];
    if isvalid(F.timer); stop(F.timer); end   % (its StopFcn deletes it)
end
if isempty(h) || ~isvalid(h); return; end
F = struct('handle', h, 'prop', "", 'saved', []);
if isprop(h, 'BackgroundColor')
    F.prop = "BackgroundColor";
    F.saved = h.BackgroundColor;
    h.BackgroundColor = [1.00 0.90 0.35];
elseif isprop(h, 'FontWeight')
    F.prop = "FontWeight";
    F.saved = h.FontWeight;
    h.FontWeight = "bold";
end
F.timer = timer('StartDelay', 1.6, 'ExecutionMode', 'singleShot', 'TimerFcn', @(t, ~) unflash(obj, t), ...
    'StopFcn', @(t, ~) delete(t));
obj.FigureFlash = F;
start(F.timer);
end


function unflash(obj, t)
%unflash  The highlight's time is up: the label or control as it was.
if isvalid(obj) && isstruct(obj.FigureFlash) && isequal(obj.FigureFlash.timer, t)
    restore(obj.FigureFlash);
    obj.FigureFlash = [];
end
end


function restore(F)
if F.prop ~= "" && isvalid(F.handle)
    try F.handle.(F.prop) = F.saved; catch; end
end
end
