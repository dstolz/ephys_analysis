function keepFigurePicker(obj)
%keepFigurePicker  Keep the observation picker's list as the selected figure has it, to show it again when the figure comes back.
%   FigurePickers(id) becomes the picker's items (Items, ItemsData), its
%   UserData (the key it was listed for, its error, a session figure's
%   sessions), the table (FigureObservations) and the Observations
%   section's count line. refreshFigureObservations keeps the list each
%   time it makes one (and markObservations after the marks change), and
%   takes it back (takeFigurePicker) when the figure is shown again and
%   its key is the same: then figureObservations is not run again. A list
%   whose key is another figure's, or that has none (no figure, no
%   dataset), is not kept; the lists of figures gone from the config are
%   dropped here. A scan, another config and a star or note set
%   (refreshFavorites, refreshNotes) forget them all (forgetFigurePickers).
%
%   See also takeFigurePicker, forgetFigurePickers, refreshFigureObservations.
M = obj.FigurePickers;
k = obj.SelectedFigure;
if ~isa(M, 'containers.Map') || k < 1 || k > numel(obj.Config.Figures); return; end
dd = obj.FigureObservationDropDown;
U = dd.UserData;
id = obj.Config.Figures(k).id;
if ~(isstruct(U) && isfield(U, 'key') && isfield(U.key, 'id') && U.key.id == id); return; end
ids = keys(M);
gone = ~ismember(string(ids), obj.Config.figureIds());
if any(gone); remove(M, ids(gone)); end
M(char(id)) = struct('Items', {dd.Items}, 'ItemsData', dd.ItemsData, 'UserData', U, ...
    'Table', obj.FigureObservations, 'Count', string(obj.FigureEditor.obsCount.Text));
end
