function showPanelPlace(obj)
%showPanelPlace  The Panels section's place rows for the selected figure and panel, in the units picked.
%   showPanelPlace(OBJ) shows the Units drop-down (FigureRectUnits), the
%   selected panel's line ("psth_1 (PSTH): 10.2 x 6.0 cm at 0, 0":
%   rectText; with several selected, "3 panels: psth_1, psth_2, raster_1") and its rect in the Position and Size fields, the figure's
%   Boxes mean and Padding, and Snap with its step (FigureSnap,
%   FigureSnapStep, in the units picked: snapStepIn), each value converted
%   to the units on the figure's export page (figurePage) and rounded as
%   the fields show it (unitsShown). The page, dpi and units it showed
%   them on, and the panel whose rect they show, are kept in the Units
%   drop-down's UserData, so that gatherFigureEditor reads the fields back
%   on the same page, into that panel only (a value is written only where
%   the field no longer shows what was shown here).
%   No callback runs meanwhile (Applying). Called by applyFigureEditor,
%   syncFigureEditor (an edit, the page resized), onRectUnitsChanged and
%   onSnapChanged.
%
%   See also gatherFigureEditor, figurePage, unitsShown, rectText.
E = obj.FigureEditor;
if ~isfield(E, 'rectUnits') || ~isvalid(E.rectUnits); return; end
wasApplying = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, wasApplying));
u = obj.FigureRectUnits;
if ~ismember(u, EphysAnalysisConfig.RectUnits); u = "cm"; obj.FigureRectUnits = u; end
[pageCm, dpi] = figurePage(obj);
E.rectUnits.Value = u;
E.rectUnits.UserData = struct('page', pageCm, 'dpi', dpi, 'units', u, 'panel', "");
word = u;
if u == "normalized"; word = "0-1"; end
set([E.rectXYUnits E.rectWHUnits E.paddingUnits E.snapUnits], "Text", word);
E.snap.Value = obj.FigureSnap;
st = snapStepIn(obj.FigureSnapStep, u, pageCm, dpi);
obj.FigureSnapStep = st;
E.snapStep.Value = st.value;
[~, d] = unitsShown([], "", u);
E.padding.Step = max(10^-d, round(figureRectConvert(0.05, "cm", u, pageCm, dpi, "x"), d));   % a step about 0.5 mm
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
L = fig.layout;
if ismember(L.boxesMean, string(E.boxesMean.ItemsData)); E.boxesMean.Value = L.boxesMean; end
E.padding.Value = max(0, unitsShown(double(L.padding), "cm", u, pageCm, dpi, "x"));
j = obj.SelectedPanel;
if j < 1 || j > numel(fig.panels); return; end
p = fig.panels(j);
E.rectUnits.UserData.panel = p.id;   % the fields hold this panel's rect
r = double(p.rect);
if numel(r) ~= 4 || ~all(isfinite(r)); r = [0 0 1 1]; end   % (Validate reports a bad one)
v = unitsShown(r, "normalized", u, pageCm, dpi, "rect");
E.rectX.Value = v(1);
E.rectY.Value = v(2);
E.rectW.Value = v(3);
E.rectH.Value = v(4);
PT = EphysAnalysisConfig.panelTypes();
label = PT.Label(PT.Type == p.type);
if isempty(label); label = p.type; end
E.selPanel.Text = p.id + " (" + label + "): " + rectText(r, u, pageCm, dpi);
sel = selectedPanelIds(obj);
if numel(sel) > 1; E.selPanel.Text = sprintf("%d panels: %s", numel(sel), strjoin(sel, ", ")); end   % (Shift+click: each keeps its place)
end


function setApplying(obj, tf)
obj.Applying = tf;
end
