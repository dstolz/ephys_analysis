function T = figureSettingParts()
%figureSettingParts  The parts of a figure's settings that copy from one figure to another.
%   T = figureSettingParts() has one row per part, in the figure editor's
%   order (copyFigureSettings copies them):
%     Part         "observe", "alignment", "common", "arrangement", "style",
%                  "looks" or "sessions"
%     Label        name shown in the app
%     Fields       the Figure fields it copies (a string row)
%     Description  one line, the window's tooltip
%   A figure's id, title and enabled are never copied. Every part fits
%   every figure: a figure's fields do not depend on its panels.
%
%   See also copyFigureSettings, plotSettingParts.
rows = {
    "observe",     "Observations",           "observe",                      "What the figure is drawn for: the observation kind, the unit filter, the signal and channels, per trial group"
    "alignment",   "Alignment",              ["ref" "window" "selection"],   "The figure's event reference, epoch window and trial selection"
    "common",      "Common options",         "common",                       "The bins, measure, baseline, mask after stop and waveform every linked panel takes"
    "arrangement", "Arrangement and panels", ["grid" "panels"],              "The grid and every panel, with its type, options, alignment and layers (panel ids kept)"
    "style",       "Appearance",             "style",                        "Line widths, error bands, colors, fonts, legend, sorting and labels"
    "looks",       "Remembered looks",       "aesthetics",                   "The looks remembered from the preview's right-click editor"
    "sessions",    "Across sessions",        "sessions",                     "Drawn across the datasets: which ones, the figures, colors, error band, matching and trial groups"
    };
Part = [rows{:, 1}].';
Label = [rows{:, 2}].';
Fields = rows(:, 3);
Description = [rows{:, 4}].';
T = table(Part, Label, Fields, Description);
end
