function A = alignmentOf(fig, p, D)
%alignmentOf  The event reference, window and trial selection figure FIG (its panel P, [] for the figure) is drawn with.
%   A struct of ref, window and selection: the panel's own, else the
%   figure's own, else the Defaults D's (EventRef, Window, Selection).
%   Where an edit of one field of them goes to a figure or panel that
%   uses another's, it starts from these (changeTargets, applyChanges).
A = struct('ref', D.EventRef, 'window', D.Window, 'selection', D.Selection);
for f = ["ref" "window" "selection"]
    if isstruct(fig.(f)); A.(f) = fig.(f); end
    if ~isempty(p) && isstruct(p.(f)); A.(f) = p.(f); end
end
end
