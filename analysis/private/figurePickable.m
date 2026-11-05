function figurePickable(axs, fcn)
%figurePickable  A Ctrl+Click, Shift+Click (or right-click) on AXS or anything drawn in them calls FCN(CTRL, SHIFT): whether Ctrl and Shift were down.
%   A plain click and a double click do not. A click goes to the object under the pointer only (a line does not
%   pass it to its axes), so each one that has no ButtonDownFcn of its own
%   gets the callback; the axes themselves take it over their whole area.
%
%   See also renderFigure, renderProbeFigure.
for ax = reshape(axs, 1, [])
    ax.PickableParts = 'all';
    for o = reshape(findall(ax, '-property', 'ButtonDownFcn'), 1, [])
        if isempty(o.ButtonDownFcn); o.ButtonDownFcn = @(src, ~) ctrlClicked(src, fcn); end
    end
end
end


function ctrlClicked(src, fcn)
%ctrlClicked  Call FCN(CTRL, SHIFT) when the click on SRC was a Ctrl+Click, a Shift+Click or a right-click.
%   CTRL tells whether Ctrl (Cmd) was down, SHIFT whether Shift was (the
%   figure's modifiers, or its "extend" click: a Shift+Click).
fig = ancestor(src, 'figure');
if isempty(fig); return; end
try
    mods = string(fig.CurrentModifier);
catch
    mods = strings(1, 0);
end
type = string(fig.SelectionType);
ctrl = any(ismember(mods, ["control" "command"]));
shift = any(mods == "shift") || type == "extend";
if type ~= "open" && (ctrl || shift || type == "alt"); fcn(ctrl, shift); end   % (Ctrl+Click reports 'alt', as a right-click does)
end
