function figurePickable(axs, fcn)
%figurePickable  A Ctrl+Click (or right-click) on AXS or anything drawn in them calls FCN(CTRL): CTRL is whether Ctrl was down.
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
%ctrlClicked  Call FCN(CTRL) when the click on SRC was a Ctrl+Click or a right-click, CTRL telling whether Ctrl (Cmd) was down.
fig = ancestor(src, 'figure');
if isempty(fig); return; end
try
    ctrl = any(ismember(fig.CurrentModifier, {'control', 'command'}));
catch
    ctrl = false;
end
if ~strcmp(fig.SelectionType, 'open') && (ctrl || strcmp(fig.SelectionType, 'alt')); fcn(ctrl); end   % (Ctrl+Click reports 'alt', as a right-click does)
end
