function n = brokenGraphicTips(root)
%brokenGraphicTips  Over each "cannot draw" sign in ROOT, a clear image whose tooltip is the sign's message, so hovering shows why.
%   N = brokenGraphicTips(ROOT) for the signs brokenGraphic drew under ROOT
%   (renderFigure's and renderProbeFigure's canvas, once laid out). Each
%   sign whose axes sit in a panel or tab of a visible figure (the analysis
%   app's preview) gets a transparent image (uiimage, Tag "layerNoteTip")
%   over it, at its size: its tooltip is the message (wrapped), and a
%   click on it shows the whole message in a window over the figure, as a
%   click on the sign does. The image is the app's, not the figure's: it
%   follows the sign (brokenGraphic's listener) and goes with it. A sign
%   that has one keeps it; one that lost it (a drawing with Reuse keeps a
%   panel's axes and empties the rest) gets a new one. A sign in a figure
%   window gets none (print cannot write a figure holding UI components as
%   SVG): there a click on the sign shows the message, and it is the sign's
%   data tip. N: the images made.
%
%   See also brokenGraphic, renderFigure, renderProbeFigure.
n = 0;
if isempty(root) || ~isgraphics(root); return; end
fig = ancestor(root, 'figure');
if isempty(fig) || ~strcmp(fig.Visible, 'on'); return; end
signs = findall(root, '-function', @(o) isappdata(o, 'LayerNoteSign'));
blank = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'icons', 'status', 'clear.svg');   % (an empty source shows a placeholder picture)
for fr = reshape(signs, 1, [])
    U = getappdata(fr, 'LayerNoteSign');
    if ~isempty(U.overlay) && isvalid(U.overlay); continue; end
    ax = ancestor(fr, 'axes');
    if isempty(ax); continue; end
    host = ax.Parent;
    if ~(isa(host, 'matlab.ui.container.Panel') || isa(host, 'matlab.ui.container.Tab')); continue; end
    show = U.show;
    U.overlay = uiimage(host, 'ImageSource', blank, 'ScaleMethod', 'fill', 'Tag', 'layerNoteTip', ...
        'Tooltip', U.lines, 'ImageClickedFcn', @(~, ~) show());
    setappdata(fr, 'LayerNoteSign', U);
    U.place();
    n = n + 1;
end
end
