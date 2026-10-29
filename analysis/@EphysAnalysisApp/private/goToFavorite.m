function goToFavorite(obj, e, opts)
%goToFavorite  Go to the favorite E (one row of FavoriteEntries): its dataset becomes the active one.
%   A starred unit or channel is then picked in the Figures tab's
%   observation list when the figure selected there observes that kind --
%   sorted units for a unit; channels or detection channels for a channel --
%   and keeps it: on the Figures tab it is drawn (onFigureObservationChanged),
%   on another tab it waits for the Figures tab. Otherwise the status bar
%   says why it is not shown (the figure observes something else, or its
%   filter leaves it out). Used by onFavoritePicked and, for the first
%   starred unit, by onScan.
%
%   See also onFavoritePicked, onScan.
arguments
    obj (1,1) EphysAnalysisApp
    e table
    opts.What (1,1) string = "Favorite"   % how the status bar names it ("Note": goToNote)
end
if isempty(obj.Runner) || e.dataset < 1 || e.dataset > numel(obj.Runner.Keys); return; end
moved = e.dataset ~= obj.ActiveIdx;
if moved
    auto = obj.FigureAutoCheckBox.Value;
    if e.level ~= "dataset"; obj.FigureAutoCheckBox.Value = false; end   % the unit or channel is drawn below, not the first one first
    restore = onCleanup(@() set(obj.FigureAutoCheckBox, 'Value', auto));
    obj.selectDataset(e.dataset);
    clear restore
end
if e.level == "dataset"
    obj.setStatus(opts.What + ": " + e.label + " is the active dataset.");
    return
end
[row, why] = favoriteRow(obj, e);
if row == 0
    if moved; obj.autoFigurePreview(); end
    obj.setStatus(opts.What + ": " + e.label + " is the active dataset; " + why + ".");
    return
end
fd = obj.FigureObservationDropDown;
fd.Value = row;
if obj.Tabs.SelectedTab == obj.TabFigures
    obj.onFigureObservationChanged();   % remembers it and draws it
else
    k = obj.SelectedFigure;
    obj.FigureObservation(char(obj.Config.Figures(k).id)) = obj.FigureObservations.label(row);
    obj.FigureObsPrevButton.Enable = matlab.lang.OnOffSwitchState(row > 1);
    obj.FigureObsNextButton.Enable = matlab.lang.OnOffSwitchState(row < height(obj.FigureObservations));
    syncStarButtons(obj);
    if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
end
obj.setStatus(opts.What + ": " + e.label + ", picked in the Figures tab's observation list.");
end


function [row, why] = favoriteRow(obj, e)
%favoriteRow  The row of FigureObservations that is the starred unit or channel E (0: none, WHY says why).
row = 0;
why = "";
k = obj.SelectedFigure;
T = obj.FigureObservations;
if k < 1 || k > numel(obj.Config.Figures)
    why = "add a figure on the Figures tab to preview its " + e.level;
    return
end
fig = obj.Config.Figures(k);
if fig.sessions.enabled
    why = "the figure """ + fig.id + """ is drawn across sessions";
    return
end
if fig.probe.enabled
    why = "the figure """ + fig.id + """ lays every " + e.level + " out on the probe";
    return
end
ob = obj.Config.figureFor(k).observe;
if e.level == "unit" && ~(ob.kind == "unit" && ob.data == "units")
    why = "the figure """ + fig.id + """ does not observe sorted units";
    return
elseif e.level == "channel" && ~(ob.kind == "channel" || (ob.kind == "unit" && ob.data == "detected"))
    why = "the figure """ + fig.id + """ does not observe channels";
    return
end
if istable(T) && height(T) > 0
    if e.level == "unit"
        r = find(T.unitId == e.id, 1);
    else
        r = find(T.channel == e.id, 1);
    end
    if ~isempty(r); row = r; return; end
end
why = "the figure """ + fig.id + """ does not list it (its Observations section leaves it out)";
end
