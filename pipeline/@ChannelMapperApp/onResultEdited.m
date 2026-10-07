function onResultEdited(obj, evt)
%onResultEdited  A kcoords cell of the result table was edited: set that site's group.
%   Only the kcoords column is editable. A value that is not a whole number
%   from 0 is refused and the table shows the old one again.
row = evt.Indices(1);
if row < 1 || row > numel(obj.ResultOrder)
    return
end
site = obj.Result.Table.Site(obj.ResultOrder(row));
try
    obj.setKCoords(site, double(evt.NewData));
    obj.setStatus(sprintf('Site %g: kcoords %g.', site, evt.NewData), false);
catch ME
    obj.setStatus(ME.message, true);
    obj.refreshResultTable();
end
end
