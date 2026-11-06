function figurePickable(axs, fcn)
%figurePickable  A Ctrl+Click, Shift+Click (or right-click) on AXS or anything drawn in them calls FCN(CTRL, SHIFT): whether Ctrl and Shift were down.
%   A plain click and a double click do not. A click goes to the object
%   under the pointer only (a line does not pass it to its axes), so each
%   one that has no ButtonDownFcn of its own gets the callback; the axes
%   themselves take it over their whole area. FCN is kept on each axes
%   (appdata FigurePickFcn) and found from the clicked object when it is
%   clicked, so a panel a drawing with Reuse kept, whose objects have the
%   callback already, takes the new FCN with no walk over them: the
%   objects with no ButtonDownFcn yet are found in one search and given it
%   in one set.
%
%   See also renderFigure, renderProbeFigure.
for ax = reshape(axs, 1, [])
    setappdata(ax, 'FigurePickFcn', fcn);
    ax.PickableParts = 'all';
    objs = findall(ax, 'ButtonDownFcn', '');   % (a kept panel's objects have it: only new ones)
    if ~isempty(objs); set(objs, 'ButtonDownFcn', @clicked); end
end
end


function clicked(src, ~)
%clicked  Call its axes' FigurePickFcn with whether Ctrl and Shift were down, when the click on SRC was a Ctrl+Click, a Shift+Click or a right-click.
%   CTRL tells whether Ctrl (Cmd) was down, SHIFT whether Shift was (the
%   figure's modifiers, or its "extend" click: a Shift+Click).
ax = src;
if ~isa(ax, 'matlab.graphics.axis.AbstractAxes'); ax = ancestor(src, 'axes'); end
if isempty(ax) || ~isappdata(ax, 'FigurePickFcn'); return; end
fcn = getappdata(ax, 'FigurePickFcn');
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
