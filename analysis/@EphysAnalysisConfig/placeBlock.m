function [fig, ids] = placeBlock(fig, block, where, anchorId, rect, opts)
%placeBlock  Add another figure's panels to a figure as one block, their arrangement kept.
%   [FIG, IDS] = EphysAnalysisConfig.placeBlock(FIG, BLOCK) adds every
%   panel of BLOCK (a figure entry, normalizeFigure'd: a figure saved as a
%   panel type, FigureTemplate.panelTypes) to figure FIG in the largest
%   empty rectangle of its page, keeping the block's own arrangement: the
%   block's page ([0 0 1 1]) is mapped onto that rectangle, and so is
%   every block panel's rect (x' = x0 + x * w0, y' = y0 + y * h0, width
%   and height scaled by w0 and h0), so a raster flush over its PSTH
%   stays flush and in the same proportions.
%   [FIG, IDS] = EphysAnalysisConfig.placeBlock(FIG, BLOCK, WHERE,
%   ANCHORID, RECT) picks that rectangle as placePanel picks a new
%   panel's:
%     "free"   (the default) the largest empty rectangle (freeRect); none:
%              "below" ANCHORID; no anchor either: NoRoom
%     "below" / "above" / "left" / "right"
%              the anchor's rect cut in two flush halves (splitRect): the
%              anchor keeps the half next to that side, the block fills
%              the half on it
%     "rect"   RECT ([x y width height], 0-1 of the page), clipped to the
%              page
%   A figure without panels takes the block over its whole page: the
%   block's panels with their rects as they are; ANCHORID is then not
%   needed.
%
%   The panels keep their type, options, layers, alignment, note and
%   overlays, and their order (the block's last on top), after FIG's own.
%   A panel id FIG has already becomes "<type>_<n>" (the smallest n
%   free). IDS: the block's panels' ids in FIG, in the block's order
%   (FIG.panels(end-numel(IDS)+1:end)).
%   Alignment="own" gives each panel that takes the figure's event
%   reference, window or trial selection ("default") the block's own, when
%   the block has its own (a struct); "figure" (the default) leaves them
%   "default": they follow FIG's.
%   BLOCK's other settings (what it observes, its page size, layout,
%   latency, appearance, looks, sessions and probe layout) are not used:
%   FIG keeps its own.
%
%   Errors: EphysAnalysisConfig:NoPanel (BLOCK has no panel; beside: no
%   anchor, or no such panel), EphysAnalysisConfig:BadRect,
%   EphysAnalysisConfig:NoRoom (as placePanel).
%
%   See also EphysAnalysisConfig.placePanel, FigureTemplate.panelTypes,
%   EphysAnalysisConfig.removePanel.

arguments
    fig (1,1) struct
    block (1,1) struct
    where (1,1) string {mustBeMember(where, ["free" "below" "above" "left" "right" "rect"])} = "free"
    anchorId (1,1) string = ""
    rect double = []
    opts.Alignment (1,1) string {mustBeMember(opts.Alignment, ["figure" "own"])} = "figure"
end

B = EphysAnalysisConfig.normalizeFigure(block, "block");
if isempty(B.panels)
    error('EphysAnalysisConfig:NoPanel', 'The figure placed has no panel.');
end
P = B.panels;
if opts.Alignment == "own"   % the block's own event, window and selection, where its panels take the figure's
    for f = ["ref" "window" "selection"]
        if ~isstruct(B.(f)); continue; end
        for k = 1:numel(P)
            if ~isstruct(P(k).(f)); P(k).(f) = B.(f); end
        end
    end
end
taken = string.empty(1, 0);
if ~isempty(fig.panels); taken = [fig.panels.id]; end
for k = 1:numel(P)
    if ismember(P(k).id, taken); P(k).id = EphysAnalysisConfig.freeId(P(k).type, taken); end
    taken(end+1) = P(k).id; %#ok<AGROW>
end
ids = [P.id];

[fig, t] = placeTarget(fig, where, anchorId, rect, "the panels");
for k = 1:numel(P)   % the block's page onto the target
    r = P(k).rect;
    P(k).rect = [t(1) + r(1) * t(3), t(2) + r(2) * t(4), r(3) * t(3), r(4) * t(4)];
end
if isempty(fig.panels)
    fig.panels = P;
else
    fig.panels = [fig.panels, P];
end
end
