function markLookEdited(obj, holder, t, evt)
%markLookEdited  An edit in the plot editor's "Each mark" table T: one mark's look.
%   Row R of T is mark R of the plot's rasterEvents, kept in HOLDER (the
%   Sequences label: setSequenceHolder). Its marker, size or color is
%   changed there, and the plot then changes (onConfigChanged). A size that
%   is not positive, or a color that is not one (nor "auto"), is undone.
%
%   See also markLookTable, editSequence.
r = evt.Indices(1);
c = evt.Indices(2);
D = t.Data;
col = string(D.Properties.VariableNames{c});
marks = holder.UserData;
if r > numel(marks); return; end
bad = false;
switch col
    case "Marker"
        C = PlotAesthetics.catalog().Marker;
        marks(r).marker = C.Choices(string(C.ChoiceLabels) == string(evt.NewData));
    case "Size"
        bad = ~(isnumeric(evt.NewData) && isscalar(evt.NewData) && evt.NewData > 0 && isfinite(evt.NewData));
        if ~bad; marks(r).size = double(evt.NewData); end
    case "Color"
        txt = strtrim(string(evt.NewData));
        if any(lower(txt) == ["" "auto"])
            marks(r).color = "";
        else
            try
                validatecolor(txt);
                marks(r).color = txt;
            catch
                bad = true;
            end
        end
end
if bad
    D{r, c} = evt.PreviousData;
    t.Data = D;
    obj.setStatus("A mark's size is a positive number of points, and its color auto, a name or #RRGGBB.");
    return
end
setSequenceHolder(holder, marks);
obj.onConfigChanged("plot");
end
