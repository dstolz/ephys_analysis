function [S, h] = formLayout(S)
%formLayout  Pack a section's shown rows to the top and size it.
%   [S, H] = formLayout(S) gives the section's shown rows (S.Shown) the
%   first rows of its body and the hidden ones zero-height rows below them,
%   out of sight, so hidden rows leave no gaps; sets the header's arrow and
%   title; and returns the section's height H in pixels: 0 when it is hidden
%   (S.Visible false, or a form with no row shown), the header's alone when
%   it is collapsed. A section with a key (S.Key, "1" to "9" or "0") names it in
%   its header: "(Ctrl+1)", "(Cmd+1)" on a Mac.
%
%   The first call finds each row's controls (the body's children in that
%   row); rows are addressed by that first order from then on. Only what
%   changes is set: a set of a UI component's property costs as much when
%   its value stays, and the editor lays out every section on each edit.
%
%   See also formSection, formRow, formShow.
header = 26 * ~isempty(S.Toggle);
isForm = ~isempty(S.Heights);
if isForm
    if all(cellfun(@isempty, S.Items))
        for c = reshape(S.Body.Children, 1, [])
            r = c.Layout.Row(1);
            S.Items{r}(end+1) = c;
        end
    end
    on = S.Shown;
    order = [find(on) find(~on)];
    for i = 1:numel(order)
        vis = matlab.lang.OnOffSwitchState(on(order(i)));
        for c = S.Items{order(i)}
            if ~isequal(c.Layout.Row, i); c.Layout.Row = i; end
            if c.Visible ~= vis; c.Visible = vis; end
        end
    end
    n = nnz(on);
    setChanged(S.Body, 'RowHeight', num2cell([S.Heights(on) zeros(1, nnz(~on))]));
    body = sum(S.Heights(on)) + max(0, n - 1) * S.Body.RowSpacing + S.Body.Padding(2) + S.Body.Padding(4);
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


function setChanged(h, prop, v)
%setChanged  Set property PROP of H to V unless it holds V already (a set costs as much when nothing changes).
if ~isequal(h.(prop), v)
    h.(prop) = v;
end
end
