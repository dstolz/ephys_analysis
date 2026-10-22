function T = figureSizePresets()
%figureSizePresets  The suggested page sizes of the Figures tab's Size drop-down.
%   T = figureSizePresets() has one row per suggestion, in the drop-down's
%   order:
%     Label    the text the drop-down shows (and takes back)
%     Width    the page's width in Units (NaN: no size of its own)
%     Height   its height
%     Units    "px" (pixels of the exported PNG, at the Export dpi), "in"
%              or "cm"; "" for the two rows without a size
%   "Export tab size" is a figure's size.source "export" (the Export tab's
%   Width and Height); "Fit preview" takes the shape and size of the
%   preview area as it is (the app fills Width and Height in). The others
%   are own sizes: 700 x 800 px is the page the shared y range of a run
%   is measured on (figureYExtents), the journal columns are the common
%   single, 1.5 and double column widths, and the slide is 16:9.
%
%   See also figureSizeParse, figureExportSize.
rows = {
    "Export tab size",                       NaN,   NaN, ""
    "700 x 800 px",                          700,   800, "px"
    "Journal 1 column (3.5 x 3 in)",         3.5,   3,   "in"
    "Journal 1.5 column (5 x 4 in)",         5,     4,   "in"
    "Journal 2 column (7 x 4.5 in)",         7,     4.5, "in"
    "Slide 16:9 (13.33 x 7.5 in)",           13.33, 7.5, "in"
    "Square (4 x 4 in)",                     4,     4,   "in"
    "Fit preview",                           NaN,   NaN, ""
    };
Label = [rows{:, 1}].';
Width = [rows{:, 2}].';
Height = [rows{:, 3}].';
Units = [rows{:, 4}].';
T = table(Label, Width, Height, Units);
end
