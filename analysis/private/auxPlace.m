function place = auxPlace(opt, rateStacked)
%auxPlace  Where the mean aux signal goes: its placement, "below" where "over" has no room.
%   PLACE = auxPlace(OPT, RATESTACKED): OPT.placement ("below", "above" or
%   "over"; a plot's aux settings, defaults("Aux")); "over" is "below"
%   under a stacked PSTH (RATESTACKED: its right axis is its rows' peaks)
%   and for a heat map (an image does not go on the right axis of a plot).
%
%   See also auxInto, renderPSTH, renderRaster, plotCaption.
place = string(opt.placement);
if place == "over" && (rateStacked || string(opt.display) == "heatmap")
    place = "below";
end
end
