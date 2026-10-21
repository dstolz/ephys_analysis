function [level, id, why] = observedItem(obj)
%observedItem  What the observation picked over the figure preview stars, or has a note on: its level and id, or why it has none.
%   LEVEL "unit" (a sorted unit: ID its cluster id), "channel" (a channel,
%   or a detection channel: ID its recording channel) or "dataset" (ID
%   NaN); WHY is "" then, else says why nothing can be starred or have a note (no scan,
%   no figure, a figure across sessions, nothing picked, an AUX channel).
%
%   See also onStarToggled, syncStarButtons, favoriteMarks.
level = "";
id = NaN;
why = "";
k = obj.SelectedFigure;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if isempty(obj.Runner) || obj.ActiveIdx < 1 || numel(obj.Favorites) < obj.ActiveIdx
    why = "scan and pick a dataset first";
elseif k < 1 || k > numel(obj.Config.Figures)
    why = "no figure is selected";
elseif obj.Config.Figures(k).sessions.enabled
    why = "a figure across sessions observes several datasets: pick a figure of one dataset";
elseif ~istable(T) || ~isnumeric(i) || ~isscalar(i) || i < 1 || i > height(T)
    why = "no observation is picked";
end
if why ~= ""; return; end
switch T.kind(i)
    case "dataset"
        level = "dataset";
    case "unit"
        if obj.Config.Figures(k).observe.data == "detected"
            level = "channel";
            id = T.channel(i);
        else
            level = "unit";
            id = T.unitId(i);
        end
    otherwise
        level = "channel";
        id = T.channel(i);
end
if level ~= "dataset" && ~isfinite(id)
    why = T.label(i) + " has no recording channel";
    level = "";
end
end
