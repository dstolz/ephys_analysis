function onMoveFigure(obj, step)
%onMoveFigure  Move the selected figure up (STEP -1) or down (+1) its group of the tree (the run order).
%   It swaps places with its neighbor in the tree's group (the whole list
%   when ungrouped: figureGroups), which shows as one step; the figures
%   between them keep theirs. It stays selected, its preview as it is.
k = obj.SelectedFigure;
n = numel(obj.Config.Figures);
if k < 1 || k > n; return; end
cfg = obj.gatherConfig();
F = cfg.Figures;
[~, ~, members] = figureGroups(F, string(obj.FigureGroupDropDown.Value));
group = members{cellfun(@(m) any(m == k), members)};
i = find(group == k) + step;
if i < 1 || i > numel(group); return; end
j = group(i);
F([k j]) = F([j k]);
cfg.Figures = F;
obj.SelectedFigure = j;
obj.applyConfig(cfg);
obj.setStatus("Moved " + F(j).id + " " + ternary(step < 0, "up", "down") + ".");
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
