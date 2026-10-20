function onFigureObservationChanged(obj)
%onFigureObservationChanged  Another observation picked over the preview: remember it for the figure and draw it.
%   Picking is asking to see it, so it is drawn whether or not Auto is on.
dd = obj.FigureObservationDropDown;
T = obj.FigureObservations;
k = obj.SelectedFigure;
if ~istable(T) || height(T) == 0 || k < 1 || k > numel(obj.Config.Figures); return; end
i = dd.Value;
if ~isnumeric(i) || i < 1 || i > height(T); return; end
obj.FigureObservation(char(obj.Config.Figures(k).id)) = T.label(i);
obj.FigureObsPrevButton.Enable = matlab.lang.OnOffSwitchState(i > 1);
obj.FigureObsNextButton.Enable = matlab.lang.OnOffSwitchState(i < height(T));
syncStarButtons(obj);   % the star toggle shows this one's star
obj.refreshFigurePreview();
end
