function b = starButton(obj, parent, what)
%starButton  A star toggle (a state button, "☆" / "★") that stars WHAT: "dataset" (the active one) or "observation" (the one picked).
%   Off until a scan; syncStarButtons sets its state and look, and a press
%   goes to onStarToggled.
%
%   See also syncStarButtons, onStarToggled, buildFavorites.
switch what
    case "dataset"
        tip = "Star the active dataset (a favorite): kept in <Name>_favorites.json in its output folder, " + ...
            "listed under Favorites and marked ★ in the Dataset drop-downs and the Data tab's table.";
    otherwise
        tip = "Star the observation previewed: the sorted unit (with its sort), the channel (a detection channel " + ...
            "is starred as its channel) or, for a figure of the dataset, the dataset. Listed under Favorites, marked ★ in this list.";
end
b = uibutton(parent, "state", "Text", "☆", "Enable", "off", "Tooltip", tip, ...
    "ValueChangedFcn", @(btn, ~) obj.onStarToggled(what, btn.Value));
end
