function style = renderStyle(s)
%renderStyle  A renderer's Style: the config's Style fields, normalized, and the plot design.
%   STYLE = renderStyle(S) normalizes S like EphysAnalysisConfig's Style
%   section and keeps S.Design, the design renderPlot draws with
%   (PlotDesign): its group colours (groupPalette), colormaps
%   (designColormap) and ground (paleColor). Without one, STYLE.Design is
%   the Default design, which changes nothing.
d = [];
if isstruct(s) && isfield(s, 'Design')
    d = s.Design;
    s = rmfield(s, 'Design');
end
style = EphysAnalysisConfig.normalizeSection("Style", s);
if isempty(d); d = PlotDesign.none(); end
style.Design = d;
end
