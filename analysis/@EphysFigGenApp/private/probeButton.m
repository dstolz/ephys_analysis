function b = probeButton(field, fcn)
%probeButton  A "Probe..." button beside a Channels field of the figure editor that picks the channels on the probe.
%   B = probeButton(FIELD, FCN) puts FIELD (a text field of channels) in
%   a one-row grid of its own where it was, in its grid, with the button
%   B (Tag "probePick", UserData FIELD) at its right, as colorSwatch does.
%   Pressing it calls FCN(): the app's pickChannels, which opens the
%   ProbePickDialog on the active dataset's probe. The button is enabled
%   with what the field picks (syncFigureEditor: not for AUX, which has no
%   probe).
%
%   See also EphysFigGenApp.pickChannels, ProbePickDialog, colorSwatch, buildFiguresTab.
arguments
    field (1,1)
    fcn (1,1) function_handle
end
parent = field.Parent;
heights = parent.RowHeight;    % a new child may grow the grid: put it back
widths = parent.ColumnWidth;
at = field.Layout;
g = uigridlayout(parent, [1 2], "ColumnWidth", {'1x', 86}, "RowHeight", {'1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 4);
g.Layout.Row = at.Row;
g.Layout.Column = at.Column;
field.Parent = g;
field.Layout.Row = 1;
field.Layout.Column = 1;
parent.RowHeight = heights;
parent.ColumnWidth = widths;
b = uibutton(g, "Text", "Probe...", "Icon", buttonIcon("probe"), "Tag", "probePick", "UserData", field, "ButtonPushedFcn", @(~, ~) fcn(), ...
    "Tooltip", "Pick the channels by clicking the probe of the active dataset, as in the dataset browser's Channels " + ...
    "tab: a site picks or drops its channel, a shank picks or drops the shank. OK puts them in these rows.");
b.Layout.Row = 1;
b.Layout.Column = 2;
end
