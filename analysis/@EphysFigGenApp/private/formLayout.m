function [S, h] = formLayout(S)
%formLayout  Show a section's shown rows, give the others no height, and size it.
%   [S, H] = formLayout(S) shows the section's rows S.Shown and hides the
%   others (so Tab skips them); a hidden row and the gap under it get no
%   height, so it leaves no space. Every row keeps its place in the body
%   (formRow): what changes is the body's row heights, in one set, and the
%   Visible of the rows shown or hidden. Moving rows instead (packing the
%   shown ones to the top with a new Layout.Row each) took the window about
%   three times as long to paint on a switch of panel type, with more than
%   twice the position reports from the view. It also sets the header's
%   arrow and title, and returns the section's height H in pixels: 0 when
%   it is hidden (S.Visible false, or a form with no row shown), the
%   header's alone when it is collapsed. A section with a key (S.Key, "1"
%   to "9" or "0") names it in its header: "(Ctrl+1)", "(Cmd+1)" on a Mac.
%
%   Sub-headings (formSubheading) are rows that follow the rows under
%   them: a row shows when S.Shown says so and the sub-heading it is under
%   (the last one before it) is not collapsed (S.Collapsed); a sub-heading
%   shows when any row under it is shown, collapsed or not, so the way to
%   open a group stays while the group has something to show, and goes
%   with it when every row under it is hidden. The text of a collapsible
%   one gets its arrow ("▸" folded away, "▾" open). An end marker (title "")
%   never shows, and the rows after it belong to no sub-heading. A section
%   with no row shown through its sub-headings is hidden: n counts what
%   shows.
%
%   The first call finds each row's controls (the body's children in that
%   row); rows are addressed by that first order from then on.
%
%   Only what changed is set: a control's Visible, the grids' row heights
%   and spacing and the header's text are compared first.
%
%   See also formSection, formRow, formShow.
header = 26 * ~isempty(S.Toggle);
isForm = ~isempty(S.Heights);
if isForm
    if all(cellfun(@isempty, S.Items))
        for c = reshape(S.Body.Children, 1, [])
            k = (c.Layout.Row(1) + 1) / 2;   % (row K is in grid row 2K - 1: formRow)
            S.Items{k}(end+1) = c;
        end
    end
    on = S.Shown;
    sub = find(S.Sub);
    edges = [sub numel(on) + 1];
    for j = 1:numel(sub)
        under = edges(j) + 1:edges(j + 1) - 1;   % the rows this sub-heading titles
        on(under) = S.Shown(under) & ~S.Collapsed(sub(j));
        on(sub(j)) = any(S.Shown(under)) && S.SubTitle(sub(j)) ~= "";
        if S.SubCollapsible(sub(j))
            setChanged(S.SubButton{sub(j)}, 'Text', subArrow(S.Collapsed(sub(j))) + S.SubTitle(sub(j)));
        end
    end
    for k = 1:numel(on)
        vis = matlab.lang.OnOffSwitchState(on(k));
        for c = S.Items{k}
            if c.Visible ~= vis; c.Visible = vis; end
        end
    end
    gap = S.Gap * on;
    gap(find(on, 1, 'last')) = 0;   % none under the last row shown
    setChanged(S.Body, 'RowHeight', num2cell(reshape([S.Heights .* on; gap], 1, [])));
    n = nnz(on);
    body = sum(S.Heights(on)) + sum(gap) + S.Body.Padding(2) + S.Body.Padding(4);
    visible = S.Visible && n > 0;
else
    body = S.BodyHeight;
    visible = S.Visible;
end
open = S.Expanded || header == 0;
if header > 0
    arrow = "▼";
    if ~S.Expanded; arrow = "►"; end
    headText = arrow + "  " + S.Title;
    tip = "Show or hide this section.";
    if S.Key ~= ""
        if ismac; chord = "Cmd+" + S.Key; else; chord = "Ctrl+" + S.Key; end
        headText = headText + "   (" + chord + ")";
        tip = tip + " " + chord + " goes to it, opening it if collapsed.";
    end
    setChanged(S.Toggle, 'Text', headText);
    setChanged(S.Toggle, 'Tooltip', tip);
end
setChanged(S.Body, 'Visible', matlab.lang.OnOffSwitchState(open));
setChanged(S.Grid, 'Visible', matlab.lang.OnOffSwitchState(visible));
if open
    spacing = 4 * (header > 0);
    setChanged(S.Grid, 'RowHeight', {header, body});
    setChanged(S.Grid, 'RowSpacing', spacing);
    h = header + spacing + body;
else
    setChanged(S.Grid, 'RowHeight', {header, 0});
    h = header;
end
h = h * visible;
end


function a = subArrow(collapsed)
%subArrow  A sub-heading's arrow and a space: "▸ " while the rows under it are folded away, "▾ " while they show.
if collapsed
    a = "▸ ";
else
    a = "▾ ";
end
end


function setChanged(h, prop, v)
%setChanged  Set property PROP of H to V unless it holds V already (a set costs as much when nothing changes).
if ~isequal(h.(prop), v)
    h.(prop) = v;
end
end
