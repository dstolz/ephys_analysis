function auxEdgeTicks(xa, side)
%auxEdgeTicks  Drop the y ticks of aux panels in the tenth of their height at the edge they share.
%   auxEdgeTicks(XA, SIDE): each aux panel in XA sits flush on the panel
%   next to it, below it (SIDE "bottom": the panel is above a raster or a
%   PSTH) or above it ("top": the panel is below one), so a tick label at
%   that edge would run into the other panel's. The ticks become manual;
%   call it once the limits are final (after tileTicks), as renderPSTH
%   does for its rasters.
%
%   See also auxInto, renderPSTH, renderRaster.
for ax = reshape(xa, 1, [])
    if ~isgraphics(ax); continue; end
    r = ax.YAxis(1);
    lim = double(r.Limits);
    tk = r.TickValues;
    if side == "bottom"
        keep = tk - lim(1) >= 0.1 * diff(lim);
    else
        keep = lim(2) - tk >= 0.1 * diff(lim);
    end
    if ~all(keep); r.TickValues = tk(keep); end
end
end
