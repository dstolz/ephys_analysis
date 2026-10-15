function callMarks(ax, R, u, colors, style)
%callMarks  Unit U's auROC call in each group, at the top right of AX (the title's line), in the group's color.
%   callMarks(AX, R, U, COLORS, STYLE) for a spikePSTH result R with
%   BaselineMode "auroc" (R.auroc: cutoff, direction [nUnits x nGroups],
%   settings.marks): an up arrow (modulated upwards), a down arrow or n.s.
%   per group; U = 0 (a mean over units) gives each group's count of units
%   called up and down. Nothing without a cutoff or with marks off. Tagged
%   "modMarks". Shared by renderPSTH and a figure's PSTH panel
%   (drawPsthPanel).
%
%   See also modulationWindow, renderPSTH, drawPsthPanel.
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
nG = size(A.direction, 2);
parts = strings(1, nG);
for g = 1:nG
    c = string(sprintf('\\color[rgb]{%.3f,%.3f,%.3f}', colors(g, :)));
    if u == 0
        parts(g) = c + sprintf('\\uparrow%d \\downarrow%d', sum(A.direction(:, g) == "increase"), sum(A.direction(:, g) == "decrease"));
        continue
    end
    switch A.direction(u, g)
        case "increase", parts(g) = c + "\uparrow";
        case "decrease", parts(g) = c + "\downarrow";
        case "none",     parts(g) = c + "n.s.";
        otherwise,       parts(g) = c + "-";
    end
end
tagPart(text(ax, 1, 1, strjoin(parts, "  "), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'Interpreter', 'tex', 'FontSize', style.FontSize, 'Clipping', 'off'), "modMarks");
end
