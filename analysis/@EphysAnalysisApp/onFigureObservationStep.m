function onFigureObservationStep(obj, step)
%onFigureObservationStep  Draw the previous (STEP -1) or next (+1) observation: the < and > buttons, Page Up and Page Down.
%   Nothing happens at either end of the list.
T = obj.FigureObservations;
if ~istable(T) || height(T) == 0; return; end
dd = obj.FigureObservationDropDown;
i = dd.Value + step;
if i < 1 || i > height(T); return; end
dd.Value = i;
obj.onFigureObservationChanged();
end
