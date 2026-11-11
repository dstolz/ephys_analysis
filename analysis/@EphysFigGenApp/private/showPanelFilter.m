function showPanelFilter(E, f)
%showPanelFilter  The figure editor's Filter row: filter F (a panel's options.filter) kept in E.filterText.UserData, shown in words.
%   The label says "none" or the filter in short ("Theta 4-8 Hz"), its
%   tooltip the filter in full; gatherFigureEditor reads the UserData back
%   as the panel's options.filter (applyFigureEditor and editPanelFilter
%   set it).
%
%   See also editPanelFilter, SignalFilter.describe.
f = SignalFilter.normalize(f);
E.filterText.UserData = f;
words = SignalFilter.describe(f, Short=true);
if words == ""
    E.filterText.Text = "none";
    E.filterText.Tooltip = "No filter: the panel's signal layers are read as recorded (after the Data tab's Filter..., " + ...
        "if one is set). Script name: options.filter";
else
    E.filterText.Text = words;
    E.filterText.Tooltip = SignalFilter.describe(f) + ". Each channel's whole recording is filtered before the epochs " + ...
        "are cut. Script name: options.filter";
end
end
