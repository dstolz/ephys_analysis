function onFigureSizeEdited(obj, part)
%onFigureSizeEdited  The figure editor's Size rows were edited: the page the figure is exported on.
%   onFigureSizeEdited(OBJ, PART) is the callback of the Size drop-down
%   (PART "preset"), the Width and Height fields ("width", "height"), the
%   units ("units") and Lock ratio ("lock"). The drop-down is editable:
%     Export tab size    the figure follows the Export tab's Width and
%                        Height (size.source "export"), taller when its
%                        rows need it
%     Fit preview        the preview area's shape and size as it is now,
%                        as an own size in the figure's units
%     a suggestion or    "700 x 800 px", "Journal 1 column (3.5 x 3 in)",
%     typed text         "6 x 4 in", "1200x800 px", "15 x 10"
%                        (figureSizePresets, figureSizeParse; no unit =
%                        the units shown)
%   Editing the width or height gives the figure a size of its own
%   (size.source "own"); with Lock ratio ticked the other side follows,
%   keeping the page's aspect ratio. Changing the units converts the
%   numbers (a pixel is a pixel of the exported PNG, at the Export dpi), so
%   the page stays the same size. Text that cannot be read as a size is
%   said so in the status bar and the rows go back to what they were.
%   The edit is one undo step, named after the row (onConfigChanged
%   "figuresize"): the preview is shaped like the new page (fitFigureViews)
%   and drawn again from the figure it already computed when it was
%   current (nothing is computed again: redrawFigurePreview), else it
%   waits as after any edit. Made with Ctrl held it also opens Apply to
%   figures.
%
%   See also figureExportSize, newExportFigure, showFigureSize, fitFigureViews.
arguments
    obj (1,1) EphysAnalysisApp
    part (1,1) string {mustBeMember(part, ["preset" "width" "height" "units" "lock"])}
end
k = obj.SelectedFigure;
if obj.Applying || k < 1 || k > numel(obj.Config.Figures); return; end
E = obj.FigureEditor;
fig = obj.Config.Figures(k);
dpi = obj.Config.Export.Dpi;
T = figureSizePresets();
cur = shownSize(obj, fig);   % the page as it is, in the figure's units
new = cur;
own = fig.size.source == "own";   % the edit makes it the figure's own
switch part
    case "preset"
        txt = strtrim(string(E.sizePreset.Value));
        if lower(txt) == lower(T.Label(1))
            own = false;
        else
            own = true;
            if lower(txt) == lower(T.Label(end))   % the preview area, as it is
                pos = obj.FigurePreviewHost.InnerPosition;
                px = max(pos(3:4) - 8, 1);
                new.width = roundTo(figureSizeConvert(px(1) / 96, "in", cur.units, dpi), cur.units);
                new.height = roundTo(figureSizeConvert(px(2) / 96, "in", cur.units, dpi), cur.units);
            else
                [n, ok] = figureSizeParse(txt, cur.units);
                if ~ok
                    obj.setStatus("Size not read: """ + txt + """. Type it like 6 x 4 in, 1200 x 800 px or 15 x 10 cm, or pick a suggestion.");
                    obj.showFigureSize();
                    return
                end
                new = n;
            end
        end
    case "width"
        own = true;
        new.width = E.sizeWidth.Value;
        if E.sizeLock.Value; new.height = roundTo(new.width * cur.height / cur.width, cur.units); end
    case "height"
        own = true;
        new.height = E.sizeHeight.Value;
        if E.sizeLock.Value; new.width = roundTo(new.height * cur.width / cur.height, cur.units); end
    case "units"
        u = string(E.sizeUnits.Value);
        new.width = roundTo(figureSizeConvert(cur.width, cur.units, u, dpi), u);
        new.height = roundTo(figureSizeConvert(cur.height, cur.units, u, dpi), u);
        new.units = u;
end
z = struct('source', "export", 'width', fig.size.width, 'height', fig.size.height, 'units', new.units, ...
    'lock', logical(E.sizeLock.Value));
if own
    z.source = "own";
    z.width = new.width;
    z.height = new.height;
end
if isequaln(z, fig.size)   % nothing changed (the same text again)
    obj.showFigureSize();
    return
end
obj.showFigureSize(z);
ctl = struct('preset', E.sizePreset, 'width', E.sizeWidth, 'height', E.sizeHeight, 'units', E.sizeUnits, 'lock', E.sizeLock);
obj.onConfigChanged("figuresize", ctl.(part));
end


function s = shownSize(obj, fig)
%shownSize  The page of figure FIG as the editor shows it: width, height and units (an Export tab size converted to the units).
if fig.size.source == "own"
    s = struct('width', fig.size.width, 'height', fig.size.height, 'units', string(fig.size.units));
    return
end
dpi = obj.Config.Export.Dpi;
cm = figureExportSize(obj.Config.Export, [], fig);
u = string(fig.size.units);
v = figureSizeConvert(cm, "cm", u, dpi);
s = struct('width', roundTo(v(1), u), 'height', roundTo(v(2), u), 'units', u);
end


function v = roundTo(v, units)
%roundTo  A length rounded as the editor keeps it: whole pixels, else thousandths.
if string(units) == "px"
    v = max(round(v), 1);
else
    v = max(round(v * 1000) / 1000, 0.001);
end
end
