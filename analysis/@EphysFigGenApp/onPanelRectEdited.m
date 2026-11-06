function onPanelRectEdited(obj, part)
%onPanelRectEdited  A field of the selected panel's rect typed: its x, y, width or height, in the Layout section's units.
%   onPanelRectEdited(OBJ, PART), PART "x", "y", "w" or "h" (the Position
%   and Size fields). A number that is not finite, or a width or height
%   not above 0, is refused: the status bar says so and the fields show
%   the rect as it is. Else the edit goes through onConfigChanged as one
%   step of the undo history named after the field ("Panel x", "Panel y",
%   "Panel width", "Panel height"; a burst of edits of one field is one
%   step): gatherFigureEditor converts the field to 0-1 of the page
%   (figureRectConvert, on the page the fields were shown on) and keeps
%   the rect on the page (a position moves the panel back onto it, a size
%   is cut at its edge); the fields then show the rect as stored
%   (showPanelPlace, from syncFigureEditor) and the status bar says where
%   the panel is ("psth_1: 10.2 x 6.0 cm at 0, 0"). The preview is drawn
%   again as after any edit (Auto).
%
%   See also gatherFigureEditor, showPanelPlace, figureRectConvert.
arguments
    obj (1,1) EphysFigGenApp
    part (1,1) string {mustBeMember(part, ["x" "y" "w" "h"])}
end
if obj.Applying; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
E = obj.FigureEditor;
field = E.("rect" + upper(part));
names = struct('x', "x", 'y', "y", 'w', "width", 'h', "height");
v = field.Value;
if isempty(v) || ~isscalar(v) || ~isfinite(v) || (ismember(part, ["w" "h"]) && v <= 0)
    showPanelPlace(obj);   % the rect as it is
    obj.setStatus("A panel's " + names.(part) + " is a number" + ternary(ismember(part, ["w" "h"]), " above 0", "") + ...
        ": " + obj.Config.Figures(k).panels(j).id + " keeps its place.");
    return
end
before = obj.Config.Figures(k).panels(j).rect;
obj.onConfigChanged("figure", "Panel " + names.(part));
k = obj.SelectedFigure;   % (the same figure: an edit does not change the selection)
if k < 1 || k > numel(obj.Config.Figures) || j > numel(obj.Config.Figures(k).panels); return; end
p = obj.Config.Figures(k).panels(j);
[pageCm, dpi] = figurePage(obj);
u = obj.FigureRectUnits;
if isequal(before, p.rect)
    obj.setStatus(p.id + " is at " + rectText(p.rect, u, pageCm, dpi) + " already.");
    return
end
msg = p.id + ": " + rectText(p.rect, u, pageCm, dpi) + ".";
[shownNow, d] = unitsShown(double(p.rect), "normalized", u, pageCm, dpi, "rect");
if abs(shownNow(part == ["x" "y" "w" "h"]) - round(v, d)) > 0.5 * 10^-d + 1e-9
    msg = msg + " Kept on the page.";
end
obj.setStatus(msg);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
