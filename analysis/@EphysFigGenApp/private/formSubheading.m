function [S, r, g] = formSubheading(S, key, title, opts)
%formSubheading  Add a sub-heading to a form section: a bold gray title over the rows that follow, with a control at its right and a collapse if asked.
%   [S, R, G] = formSubheading(S, KEY, TITLE) adds a row to the body of the
%   section S (formSection) that holds TITLE, bold, dark gray, 12 pt,
%   across both columns. The rows added after it (formRow) belong to it,
%   up to the next sub-heading or the section's end; they are the rows it
%   titles. KEY names the sub-heading within the section: it is how the
%   app remembers a collapsed one (preference FigureSubheadingsCollapsed
%   holds "<section name>.<KEY>") and how the callbacks find it. R is the
%   body's grid row, as formRow returns it.
%
%   formLayout hides a sub-heading while every row under it is hidden
%   (S.Shown, set by formShow), so a group with nothing to show leaves no
%   stray title; a sub-heading has no S.Shown of its own (it stays false).
%
%   Control=true makes the row a one-row grid {'1x', 'fit'} in R: the title
%   at the left, a slot at the right for one control of the caller's (a
%   "Use default" check box); G is that grid, [] without Control. Put the
%   control in G (G's column 2).
%
%   Collapsible=true makes the title a flat button -- the section's body
%   color, no border, so it reads as text -- reading "▸ TITLE" while the
%   rows under it are folded away and "▾ TITLE" while they show. A click
%   calls Callback(S.Name, KEY) (the app's onFigureSubheadingToggled, which
%   flips S.Collapsed and lays the editor out again); formLayout hides the
%   folded rows whatever S.Shown says, so Tab skips them. A collapsible
%   sub-heading starts folded away (S.Collapsed true).
%
%   TITLE "" adds an end marker instead: a row without height that closes
%   the group above, so the rows after it belong to no sub-heading (the
%   marker is never shown, and has no title, control or collapse).
%
%   A sub-heading is a row like any other in the section's vectors
%   (Heights, Keys, Items, ...) and in the search: figureSearchIndex lists
%   it by its title, and a row under it lists the title in its path.
%
%   See also formRow, formSection, formLayout, formGroup.
arguments
    S (1,1) struct
    key (1,1) string
    title (1,1) string
    opts.Control (1,1) logical = false
    opts.Collapsible (1,1) logical = false
    opts.Callback = []
end
marker = title == "";
if marker
    opts.Control = false;
    opts.Collapsible = false;
end
height = 26;   % (room above the title, whose text sits at the bottom)
if marker; height = 0; end
[S, r] = formRow(S, strings(1, 0), "", height);
k = numel(S.Heights);
S.Shown(k) = false;   % (formLayout shows it with the rows under it)
S.Sub(k) = true;
S.SubKey(k) = key;
S.SubTitle(k) = title;
S.SubCollapsible(k) = opts.Collapsible;
S.Collapsed(k) = opts.Collapsible;
g = [];
if marker; return; end
dark = [0.25 0.25 0.25];
parent = S.Body;
if opts.Control
    g = uigridlayout(S.Body, [1 2], "ColumnWidth", {'1x', 'fit'}, "Padding", [0 0 0 0], "ColumnSpacing", 6, ...
        "BackgroundColor", S.Body.BackgroundColor);
    g.Layout.Row = r;
    g.Layout.Column = [1 2];
    parent = g;
end
if opts.Collapsible
    name = S.Name;
    c = uibutton(parent, "push", "Text", arrow(true) + title, "HorizontalAlignment", "left", "FontWeight", "bold", ...
        "FontSize", 12, "FontColor", dark, "BackgroundColor", S.Body.BackgroundColor, "Tag", "formSubheadingToggle", ...
        "Tooltip", "Show or hide the rows under " + title + ".");
    if ~isempty(opts.Callback)
        c.ButtonPushedFcn = @(~, ~) opts.Callback(name, key);
    end
    S.SubButton{k} = c;
else
    c = uilabel(parent, "Text", title, "FontWeight", "bold", "FontSize", 12, "FontColor", dark, ...
        "VerticalAlignment", "bottom", "Tag", "formSubheading");
end
if opts.Control
    c.Layout.Column = 1;
else
    c.Layout.Row = r;
    c.Layout.Column = [1 2];
end
end


function a = arrow(collapsed)
%arrow  The collapse arrow and a space: "▸ " while the rows are folded away, "▾ " while they show (formLayout keeps it).
if collapsed
    a = "▸ ";
else
    a = "▾ ";
end
end
