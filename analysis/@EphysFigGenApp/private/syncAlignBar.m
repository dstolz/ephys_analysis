function syncAlignBar(obj, shown)
%syncAlignBar  Arrange's align bar shown in the templates' place while Arrange is on, its buttons on as the selection allows.
%   syncAlignBar(OBJ, SHOWN): with Arrange on (FigureArrange) the align
%   bar (FigureAlignBar) shows and the template controls above the
%   preview (FigureTemplateBar) hide, in the same cell, so the preview
%   keeps its size; off, the other way round. SHOWN: Arrange's overlay
%   shows (syncArrangeOverlay): the six align buttons are on with a panel
%   selected, Space evenly's two with two or more (selectedPanelIds).
%   The drop-downs show FigureAlignBy and FigureAlignTo, the Gap
%   FigureAlignGap in the Panels section's units (blank: even gaps).
%   Only what differs is set. Called by syncArrangeOverlay, which follows
%   the selection, the preview and the toggle.
%
%   See also EphysFigGenApp.onArrangeAlign, EphysFigGenApp.syncArrangeOverlay, figureAlign.
B = obj.FigureAlignBar;
if ~isstruct(B) || ~isvalid(B.grid); return; end
on = obj.FigureArrange;
setIf(B.grid, 'Visible', matlab.lang.OnOffSwitchState(on));
T = obj.FigureTemplateBar;
if ~isempty(T) && isvalid(T); setIf(T, 'Visible', matlab.lang.OnOffSwitchState(~on)); end
if ~on; return; end
n = numel(selectedPanelIds(obj));
for nm = ["left" "center" "right" "top" "middle" "bottom"]
    setIf(B.buttons.(nm), 'Enable', matlab.lang.OnOffSwitchState(shown && n >= 1));
end
for nm = ["spaceX" "spaceY"]
    setIf(B.buttons.(nm), 'Enable', matlab.lang.OnOffSwitchState(shown && n >= 2));
end
if ismember(obj.FigureAlignBy, string(B.by.ItemsData)); setIf(B.by, 'Value', char(obj.FigureAlignBy)); end
if ismember(obj.FigureAlignTo, string(B.to.ItemsData)); setIf(B.to, 'Value', char(obj.FigureAlignTo)); end
u = obj.FigureRectUnits;
words = struct('normalized', "0-1", 'pct', "%", 'cm', "cm", 'in', "in", 'px', "px");
key = u;
if u == "%"; key = "pct"; end
setIf(B.gapUnits, 'Text', char(words.(key)));
G = obj.FigureAlignGap;
v = [];
if isstruct(G)
    [pageCm, dpi] = figurePage(obj);
    v = unitsShown(double(G.value), string(G.units), u, pageCm, dpi, "x");
end
if ~isequal(B.gap.Value, v); B.gap.Value = v; end
end


function setIf(h, prop, v)
%setIf  H's property PROP set to V when it differs.
if ~isequal(h.(prop), v); h.(prop) = v; end
end
