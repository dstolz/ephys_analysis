function markLookTable(t, marks)
%markLookTable  Show each raster event mark's look in the plot editor's "Each mark" table T.
%   MARKS is the plot's rasterEvents as the editor holds them (EventMark
%   structs, the Sequences holder's UserData). One row per mark, in their
%   order: Mark (its eventRefLabel), Marker, Size, Color ("auto": the
%   mark's automatic color). The data is set only when it changes, so an
%   edit in progress is left alone.
%
%   See also markLookEdited, rasterMarkLabels.
labels = rasterMarkLabels(marks);
C = PlotAesthetics.catalog().Marker;
choices = C.Choices(2:end);
names = C.ChoiceLabels(2:end);
n = numel(marks);
marker = strings(n, 1); sz = zeros(n, 1); color = strings(n, 1);
for m = 1:n
    marker(m) = names(max([1 find(choices == marks(m).marker, 1)]));
    sz(m) = marks(m).size;
    color(m) = marks(m).color;
    if color(m) == ""; color(m) = "auto"; end
end
T = table(labels(:), categorical(marker, names, 'Protected', true), sz, color, ...
    'VariableNames', {'Mark', 'Marker', 'Size', 'Color'});
if isequal(t.Data, T); return; end
t.Data = T;
end
