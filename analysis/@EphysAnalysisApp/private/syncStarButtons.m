function syncStarButtons(obj)
%syncStarButtons  The star toggles show the stars of what they star: the active dataset and the observation picked.
%   "★" in gold when starred, "☆" when not; off before a scan, and the
%   observation's while nothing it shows can be starred (observedItem
%   says why, in its tooltip).
%
%   The note buttons beside them follow the same dataset and observation
%   (syncNoteButtons).
%
%   See also starButton, observedItem, onStarToggled.
syncNoteButtons(obj);
fav = [];
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1 && numel(obj.Favorites) >= obj.ActiveIdx
    fav = obj.Favorites(obj.ActiveIdx);
end
for b = [obj.AlignDatasetStar obj.FiguresDatasetStar]
    if ~isvalid(b); continue; end
    look(b, ~isempty(fav), ~isempty(fav) && fav.Dataset);
end
b = obj.FigureObservationStar;
if isempty(b) || ~isvalid(b); return; end
on = false;
[level, id, why] = observedItem(obj);
if why == "" && ~isempty(fav)
    on = fav.isStarred(level, id);
end
look(b, why == "" && ~isempty(fav), on);
tip = "Star the observation previewed: the sorted unit (with its sort), the channel (a detection channel is starred " + ...
    "as its channel) or, for a figure of the dataset, the dataset. Listed under Favorites, marked ★ in this list.";
if why ~= ""; tip = tip + " Now off: " + why + "."; end
b.Tooltip = tip;
end


function look(b, enabled, on)
%look  A star toggle's state and look.
b.Enable = matlab.lang.OnOffSwitchState(enabled);
b.Value = on;
if on
    set(b, "Text", "★", "FontColor", [0.80 0.55 0], "FontSize", 18);
else
    set(b, "Text", "☆", "FontColor", [0.35 0.35 0.35], "FontSize", 18);
end
end
