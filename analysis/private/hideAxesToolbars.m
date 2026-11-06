function hideAxesToolbars(root)
%hideAxesToolbars  Turn off the axes toolbar (the icons shown over a plot on hover) of every axes under ROOT.
%   hideAxesToolbars(ROOT) sets Toolbar.Visible "off" on ROOT's axes and
%   uiaxes (ROOT: a figure, panel, tab or axes; ROOT itself when it is one),
%   so no panel of a figure shows the toolbar, in the app's preview or in a
%   window.
%
%   See also renderFigure, renderProbeFigure.

if isempty(root) || ~isgraphics(root); return; end
A = findall(root, 'Type', 'axes');
if isempty(A); return; end
tb = get(A, 'Toolbar');
if iscell(tb); tb = [tb{:}]; end
if isempty(tb); return; end
set(tb(isvalid(tb)), 'Visible', 'off');
end
