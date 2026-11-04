function tf = takeFigurePicker(obj, key)
%takeFigurePicker  Show the observation list the selected figure kept (keepFigurePicker) when it was listed for KEY.
%   TF = takeFigurePicker(OBJ, KEY) puts the kept list back in the picker
%   (its items, UserData, FigureObservations and the count line) when the
%   figure has one and its key is KEY (refreshFigureObservations' key: the
%   figure's id, the dataset or datasets, the observe block, event,
%   selection and sort); the pick is the figure's own (FigureObservation),
%   else the first. TF is false when there is none to take: the list is
%   made again.
%
%   See also keepFigurePicker, forgetFigurePickers, refreshFigureObservations.
tf = false;
M = obj.FigurePickers;
if ~isa(M, 'containers.Map') || ~isKey(M, char(key.id)); return; end
P = M(char(key.id));
if ~isequaln(P.UserData.key, key); return; end
dd = obj.FigureObservationDropDown;
T = P.Table;
v = P.ItemsData(1);
if istable(T) && height(T) > 0
    id = char(key.id);
    i = 1;
    if isKey(obj.FigureObservation, id)
        j = find(T.label == string(obj.FigureObservation(id)), 1);
        if ~isempty(j); i = j; end
    end
    obj.FigureObservation(id) = T.label(i);
    v = i;
end
obj.FigureObservations = T;
dd.ItemsData = [];
set(dd, "Items", P.Items, "ItemsData", P.ItemsData, "Value", v);
dd.UserData = P.UserData;
obj.FigureEditor.obsCount.Text = P.Count;
tf = true;
end
