function syncRunBanner(obj)
%syncRunBanner  Show the Run tab's red banner while the Sorting tab's "Dry run" box is ticked.
%   That box (Sorting.DryRun) stays ticked between runs, and a run that only
%   writes the sorting run files looks like one that sorted. The banner
%   sits at the top of the Run tab's Steps panel; its row is closed while
%   the box is off.
%
%   See also buildRunTab, syncStepEnableStates.
b = obj.RunBanner;
if isempty(b) || ~isvalid(b); return; end
on = ~isempty(obj.DryRunCheckBox) && isvalid(obj.DryRunCheckBox) && logical(obj.DryRunCheckBox.Value);
b.Visible = on;
g = b.Parent;
if isa(g, 'matlab.ui.container.GridLayout')
    h = g.RowHeight;
    h{b.Layout.Row} = 0;
    if on; h{b.Layout.Row} = 58; end
    g.RowHeight = h;
end
end
