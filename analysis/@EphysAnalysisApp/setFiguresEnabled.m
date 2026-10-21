function setFiguresEnabled(obj, ks, how)
%setFiguresEnabled  Enable or disable figures KS (indices into Config.Figures): the figure tree's check boxes.
%   HOW: "on", "off" or "toggle" (each figure of KS to the opposite of what
%   it is). The editor's edits so far are in the config first
%   (gatherConfig); the tree, the editor's Enabled box (for the figure in
%   it) and the title follow. The preview is not redrawn: a figure's being
%   enabled changes the run, not what it draws. A change is a step of the
%   undo history (recordFigureEdit: "Enable figure", "Disable figures").
arguments
    obj (1,1) EphysAnalysisApp
    ks (1,:) double
    how (1,1) string {mustBeMember(how, ["on" "off" "toggle"])}
end
cfg = obj.gatherConfig();
n = numel(cfg.Figures);
if n == 0; return; end
ks = ks(ks >= 1 & ks <= n);
was = [cfg.Figures.enabled];
now = was;
switch how
    case "on"
        now(ks) = true;
    case "off"
        now(ks) = false;
    case "toggle"
        now(ks) = ~now(ks);
end
for k = find(now ~= was)
    cfg.Figures(k).enabled = now(k);
end
changed = now(now ~= was);
if ~isempty(changed)
    words = ["Disable" "Enable"];
    label = words(changed(1) + 1);
    if any(changed ~= changed(1)); label = "Enable / disable"; end
    nouns = ["figure" "figures"];
    recordFigureEdit(obj, cfg, label + " " + nouns(1 + (numel(changed) > 1)));
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
k = obj.SelectedFigure;
if k >= 1 && k <= n
    obj.FigureEditor.enabled.Value = cfg.Figures(k).enabled;
end
obj.refreshFigureList();
obj.updateTitle();
obj.setStatus(sprintf("%d of %d figures enabled.", nnz(now), n));
end
