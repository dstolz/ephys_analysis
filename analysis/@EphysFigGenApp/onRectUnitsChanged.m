function onRectUnitsChanged(obj)
%onRectUnitsChanged  The Panels section's Units picked: the rect, padding and snap step shown and typed in them.
%   The Units drop-down (normalized, %, cm, in or px; px at the Export
%   tab's dpi) is a preference (FigureRectUnits, saved at once: savePreferences), for
%   every figure, not part of the config: nothing is edited and no undo
%   step is made. The selected panel's Position and Size, the Padding and
%   the snap step are shown again in the new units (showPanelPlace; the
%   step keeps its length, or its share of the page: snapStepIn), and so
%   are Arrange's size labels on the preview (arrangeSizeLabels) and its
%   align bar's Gap (FigureAlignGap, converted alike: syncAlignBar). The
%   panels stay stored as 0-1 of the page.
%
%   See also showPanelPlace, figureRectConvert, EphysFigGenApp.onSnapChanged.
if obj.Applying; return; end
obj.FigureArrangeFocus = false;   % (an editor control: the arrow keys are its again)
u = string(obj.FigureEditor.rectUnits.Value);
if ~ismember(u, EphysAnalysisConfig.RectUnits); return; end
[pageCm, dpi] = figurePage(obj);
obj.FigureSnapStep = snapStepIn(obj.FigureSnapStep, u, pageCm, dpi);
G = obj.FigureAlignGap;   % the align bar's Gap: the same length, or share of the page (along its width)
if isstruct(G); obj.FigureAlignGap = struct('value', unitsShown(double(G.value), string(G.units), u, pageCm, dpi, "x"), 'units', u); end
obj.FigureRectUnits = u;
showPanelPlace(obj);
arrangeSizeLabels(obj);   % (Arrange's labels in the new units)
syncAlignBar(obj, isstruct(obj.FigureArrangeOverlay));   % (its Gap in them)
obj.savePreferences();
names = struct('normalized', "0-1 of the page", 'pct', "% of the page", 'cm', "cm", 'in', "inches", ...
    'px', sprintf("px (at %g dpi)", dpi));
key = u;
if u == "%"; key = "pct"; end
obj.setStatus("The panels' places are shown in " + names.(key) + ".");
end
