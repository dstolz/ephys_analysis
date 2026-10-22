function T = figureSettingParts()
%figureSettingParts  The parts of a figure's settings that copy from one figure to others: the top of the Copy figure settings tree.
%   T = figureSettingParts() has one row per part, in the figure editor's
%   order (figureSettingItems lists each part's settings, copyFigureSettings
%   copies them):
%     Part         "observe", "alignment", "arrangement", "panel", "style",
%                  "looks" or "sessions"
%     Label        name shown in the app
%     Description  one line
%   A figure's id (and autoId), title and enabled are never copied.
%
%   See also figureSettingItems, copyFigureSettings.
rows = {
    "observe",     "Observations",           "What the figure is drawn for: the data observed, the unit filter, the channels, per trial group"
    "alignment",   "Alignment",              "The figure's event reference, epoch window and trial selection"
    "arrangement", "Arrangement and panels", "The grid with every panel (its type, options, alignment and layers; panel ids kept), and the spacing between panels"
    "panel",       "Panel settings",         "Each panel's axes and limits, colors and lines, display, marks, analysis, size and alignment: for the panels of the figures copied onto that take them"
    "style",       "Appearance",             "Line widths, error bands, colors, fonts, legend, marks, sorting and labels"
    "looks",       "Remembered looks",       "The looks remembered from the preview's right-click editor, one by one (added to the figure's own)"
    "sessions",    "Across sessions",        "Drawn across the datasets: which ones, the figures, colors, error band, matching and trial groups"
    };
Part = [rows{:, 1}].';
Label = [rows{:, 2}].';
Description = [rows{:, 3}].';
T = table(Part, Label, Description);
end
