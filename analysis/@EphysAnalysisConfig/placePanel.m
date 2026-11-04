function fig = placePanel(fig, panel, where, anchorId, rect)
%placePanel  Add a panel to a figure: in the page's free space, beside another panel, or at a rect.
%   FIG = EphysAnalysisConfig.placePanel(FIG, PANEL) adds PANEL (a
%   partial panel struct, normalizePanel'd; an empty id becomes
%   "<type>_<n>") to figure FIG (a Figures entry) in the largest empty
%   rectangle of the page (freeRect). Its rect is set here: a rect PANEL
%   gives is not used.
%   FIG = EphysAnalysisConfig.placePanel(FIG, PANEL, WHERE, ANCHORID, RECT)
%   places it by WHERE:
%     "free"   (the default) the largest empty rectangle (freeRect, at
%              least MinSize 0.08 of the page each way); when the page has
%              none, as "below" ANCHORID, and with no ANCHORID either the
%              error NoRoom
%     "below" / "above" / "left" / "right"
%              the anchor ANCHORID's rect is cut in two flush halves
%              (splitRect): the anchor keeps the half next to that side,
%              the new panel takes the half on it (below: the anchor the
%              top half, the panel the bottom one). Nothing else moves.
%     "rect"   at RECT ([x y width height], 0-1 of the page from its
%              bottom-left corner), clipped to the page; no anchor needed
%   The first panel of a figure without panels fills the page, [0 0 1 1],
%   whatever WHERE; ANCHORID and RECT are then not needed. The new panel
%   goes last in FIG.panels: on top of any panel it overlaps (orderPanel
%   changes that). removePanel takes it out again; the anchor keeps its
%   half.
%
%   Errors: EphysAnalysisConfig:NoPanel (beside: no anchor, or no such
%   panel), EphysAnalysisConfig:DuplicatePanelId (PANEL's id is taken),
%   EphysAnalysisConfig:BadRect ("rect": not 4 finite numbers, or no
%   width or height left once clipped to the page),
%   EphysAnalysisConfig:NoRoom ("free" with no free space and no anchor).
%
%   See also EphysAnalysisConfig.placeBlock, EphysAnalysisConfig.removePanel,
%   EphysAnalysisConfig.orderPanel, EphysAnalysisConfig.freeRect.

arguments
    fig (1,1) struct
    panel = struct()
    where (1,1) string {mustBeMember(where, ["free" "below" "above" "left" "right" "rect"])} = "free"
    anchorId (1,1) string = ""
    rect double = []
end

p = EphysAnalysisConfig.normalizePanel(panel);
ids = string.empty(1, 0);
if ~isempty(fig.panels); ids = [fig.panels.id]; end
if p.id == ""
    p.id = EphysAnalysisConfig.freeId(p.type, ids);
elseif ismember(p.id, ids)
    error('EphysAnalysisConfig:DuplicatePanelId', 'The figure has a panel "%s" already.', p.id);
end
[fig, p.rect] = placeTarget(fig, where, anchorId, rect, "the panel");
if isempty(fig.panels)
    fig.panels = p;
else
    fig.panels(1, end+1) = p;
end
end
