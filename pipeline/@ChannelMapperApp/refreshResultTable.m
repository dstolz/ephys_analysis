function refreshResultTable(obj)
%refreshResultTable  obj.Result.Table, in the Sort order, into the result table.
%   Columns: Site, Row 0 (chanMap), Row 1 (as the Probe tab shows it), the
%   hardware channel, the headstage input, the headstage and package pins
%   (with the connector in brackets when the device has several), shank,
%   x, y and a flag. Rows that do not reach a recorded channel are grey.
%   obj.ResultOrder maps a table row back to its Result.Table row (the
%   table is sorted by the Sort dropdown, not by clicking a header, so rows
%   stay put).
names = {'Site', 'Row 0', 'Row 1', 'HW ch', 'HS ch', 'HS pin', 'Pkg pin', 'Shank', 'X', 'Y', 'Flag'};
tbl = obj.ResultTable;
removeStyle(tbl);
R = obj.Result;
if isempty(R)
    tbl.Data = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), 'VariableNames', names);
    obj.ResultOrder = zeros(0, 1);
    return
end
[T, order] = ChannelMap.sortTable(R.Table, string(obj.SortDrop.Value));
obj.ResultOrder = order;

pkgPin = T.PackagePin;
if numel(R.Chain.package.Faces) > 1
    has = T.PackagePin ~= "";
    pkgPin(has) = T.PackagePin(has) + " (" + T.PackageConnector(has) + ")";
end
hsPin = T.HeadstagePin;
nH = numel(R.Chain.headstages);
P = R.Path(order);
for j = 1:numel(P)
    if ~isfinite(P(j).HsIndex)
        continue
    end
    he = R.Chain.headstages(P(j).HsIndex).Entry;
    tag = strings(1, 0);
    if nH > 1
        tag(end + 1) = "#" + P(j).HsIndex; %#ok<AGROW>
    end
    if numel(he.Faces) > 1
        tag(end + 1) = he.Faces(P(j).HsFace).Id; %#ok<AGROW>
    end
    if ~isempty(tag)
        hsPin(j) = hsPin(j) + " (" + strjoin(tag, " ") + ")";
    end
end
tbl.Data = table(T.Site, T.RecordingRow0, T.RecordingRow1, T.HardwareChannel, T.HeadstageChannel, hsPin, ...
    pkgPin, T.Shank, round(T.X, 2), round(T.Y, 2), T.Flag, 'VariableNames', names);
tbl.ColumnWidth = {40, 52, 52, 54, 54, 100, 100, 52, 56, 56, 'auto'};
grey = find(T.Flag ~= "");
if ~isempty(grey)
    addStyle(tbl, uistyle('BackgroundColor', [0.9 0.9 0.9], 'FontColor', [0.35 0.35 0.35]), 'row', grey);
end
end
