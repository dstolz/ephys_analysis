function [S, h] = formLayout(S)
%formLayout  Pack a section's shown rows to the top and size it.
%   [S, H] = formLayout(S) gives the section's shown rows (S.Shown) the
%   first rows of its body and the hidden ones zero-height rows below them,
%   out of sight, so hidden rows leave no gaps; sets the header's arrow and
%   title; and returns the section's height H in pixels: 0 when it is hidden
%   (S.Visible false, or a form with no row shown), the header's alone when
%   it is collapsed.
%
%   The first call finds each row's controls (the body's children in that
%   row); rows are addressed by that first order from then on.
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
        items = S.Items{order(i)};
        for c = items
            c.Layout.Row = i;
        end
        set(items, 'Visible', matlab.lang.OnOffSwitchState(on(order(i))));
    end
    n = nnz(on);
    S.Body.RowHeight = num2cell([S.Heights(on) zeros(1, nnz(~on))]);
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
    S.Toggle.Text = arrow + "  " + S.Title;
end
S.Body.Visible = matlab.lang.OnOffSwitchState(open);
S.Grid.Visible = matlab.lang.OnOffSwitchState(visible);
if open
    S.Grid.RowHeight = {header, body};
    S.Grid.RowSpacing = 4 * (header > 0);
    h = header + S.Grid.RowSpacing + body;
else
    S.Grid.RowHeight = {header, 0};
    h = header;
end
h = h * visible;
end
