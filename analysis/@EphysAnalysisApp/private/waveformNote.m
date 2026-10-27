function [txt, draws] = waveformNote(type, layout)
%waveformNote  What the figure editor's Waveform section sets for a panel type, or why that type draws no waveform.
%   [TXT, DRAWS] = waveformNote(TYPE, LAYOUT): TYPE is a panel type
%   (panelTypes), LAYOUT a waveforms panel's options.layout ("grid", the
%   default, or "probe"). DRAWS is true for the types that draw a unit's
%   waveform (options.waveform): an inset on a raster, PSTH, firing rate or
%   tuning curve panel (EphysAnalysisConfig.WaveformInsetTypes), the panel
%   itself on a unit waveforms panel; TXT then says what the section sets
%   there. For any other type TXT says why it draws none, and what to do
%   instead, as the Stack row's reason does (figureRowReason). The
%   section's note (syncFigureEditor), and the reason the search gives for
%   a hidden Waveform row (figureRowReason, gotoFigureRow).
%
%   See also syncFigureEditor, figureRowReason, waveformInset, renderWaveforms.
arguments
    type (1,1) string
    layout (1,1) string = "grid"
end
draws = true;
alt = " Put a Unit waveforms panel beside it (Panels: New panel...) to show the unit's waveform.";
if ismember(type, EphysAnalysisConfig.WaveformInsetTypes)
    txt = "The panel's first unit's waveform, as an inset in a corner of the panel (a layer drawn as its units' " + ...
        "mean has none). Time and Amplitude set its x and y scales, Size its width and height.";
elseif type == "waveforms" && layout == "probe"
    txt = "The panel draws every unit's waveform as a glyph at its place on the probe: Size sets each glyph's " + ...
        "width and height, Amplitude whether they share one scale (with a scale bar).";
elseif type == "waveforms"
    txt = "The panel is the unit's waveform (a fixed layer of several units: their means overlaid). Its own Y " + ...
        "limits (Options), when not automatic, win over the Amplitude row.";
else
    draws = false;
    switch type
        case "heatmap"
            txt = "A heat map draws its units, or one unit's epochs, as colors over time: it has no waveform inset." + alt;
        case "corrmap"
            txt = "A unit correlation map is a units-by-units matrix, no one unit's panel: it has no waveform inset." + alt;
        case "probemap"
            txt = "A probe map draws a value per unit or site, not one unit: it has no waveform inset. A Unit waveforms " + ...
                "panel in the probe layout draws every unit's waveform at its place.";
        case {"spectrum" "spectrogram" "coherence"}
            txt = "A spectral panel's axis is frequency: it has no waveform inset." + alt;
        otherwise
            txt = "This panel draws no spikes, so no waveform: the Waveform section is for a raster, PSTH, " + ...
                "firing rate, tuning curve or unit waveforms panel.";
    end
end
end
