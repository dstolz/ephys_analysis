function fillCascade(obj)
%fillCascade  Refill the probe, package and headstage dropdowns and the rows controls.
%   Items read "<manufacturer> · <name> (<channels> ch)", "!" marking an
%   entry with problems; ItemsData are the entry ids, with a leading
%   "(none)" so Items is never empty. The chosen entries stay listed even
%   when a filter would hide them. Setting Items / Value from code does not
%   fire ValueChangedFcn; Applying is set anyway, for safety.
obj.Applying = true;
c = onCleanup(@() resetFlag(obj, 'Applying'));
b = obj.Bank;

% --- probe filters ---
setFilter(obj.ProbeManDrop, ["All", b.manufacturers("probe")]);
chans = unique([b.channelCounts("probe"), b.channelCounts("package")]);
setFilter(obj.ProbeChDrop, ["All", string(chans)]);
man = string(obj.ProbeManDrop.Value);
ch = str2double(obj.ProbeChDrop.Value);

P = b.list("probe");
if man ~= "All"
    P = P(strsOf(P, 'Manufacturer') == man);
end
if ~isnan(ch)
    P = P([P.Channels] == ch);
end
setEntries(obj.ProbeDrop, P, obj.ProbeId, b);

K = b.list("package");
if ~isnan(ch)
    K = K([K.Channels] == ch);
end
setEntries(obj.PackageDrop, K, obj.PackageId, b);

% --- headstage filters ---
setFilter(obj.HsManDrop, ["All", b.manufacturers("headstage")]);
setFilter(obj.HsChDrop, ["All", string(b.channelCounts("headstage"))]);
hman = string(obj.HsManDrop.Value);
hch = str2double(obj.HsChDrop.Value);
H = b.list("headstage");
if hman ~= "All"
    H = H(strsOf(H, 'Manufacturer') == hman);
end
if ~isnan(hch)
    H = H([H.Channels] == hch);
end
setEntries(obj.HsDrop, H, obj.HeadstageId, b);
obj.HsCountSpinner.Value = obj.HeadstageCount;

% --- recording rows ---
obj.RowsModeDrop.Value = char(obj.RowsMode);
obj.ChooseDatasetButton.Enable = onoff(obj.RowsMode == "dataset");
obj.CustomRowsField.Editable = onoff(obj.RowsMode == "custom");
switch obj.RowsMode
    case "in-order"
        obj.CustomRowsField.Value = '';
        obj.CustomRowsField.Placeholder = '(every headstage channel, in ascending order)';
    case "dataset"
        obj.CustomRowsField.Value = char(compactRanges(obj.ChannelNumbers));
    case "custom"
        obj.CustomRowsField.Value = char(compactRanges(obj.ChannelNumbers));
        obj.CustomRowsField.Placeholder = 'e.g. 0-31, 32-63 (0-based hardware numbers, in recording order)';
end
if obj.RowsMode == "dataset"
    obj.ChooseDatasetButton.Text = char("Dataset: " + obj.DatasetName);
else
    obj.ChooseDatasetButton.Text = 'Choose dataset...';
end
end


function setFilter(dd, items)
%setFilter  A filter dropdown's items, keeping its value when still there.
items = unique(items, 'stable');
old = string(dd.Value);
dd.Items = cellstr(items);
if any(items == old)
    dd.Value = char(old);
else
    dd.Value = char(items(1));
end
end


function setEntries(dd, E, current, bank)
%setEntries  An entry dropdown: "(none)", the entries, and the current one if filtered out.
ids = strsOf(E, 'Id');
if current ~= "" && ~any(ids == current) && bank.has(current)
    E = [E; bank.get(current)];
    ids = strsOf(E, 'Id');
end
labels = strings(1, numel(E));
for k = 1:numel(E)
    labels(k) = sprintf("%s · %s (%g ch)", E(k).Manufacturer, E(k).Name, E(k).Channels);
    if ~isempty(E(k).Problems)
        labels(k) = labels(k) + "  !";
    end
end
dd.Items = cellstr(["(none)", labels]);
dd.ItemsData = cellstr(["", ids]);
if current ~= "" && any(ids == current)
    dd.Value = char(current);
else
    dd.Value = '';
end
end


function s = compactRanges(v)
%compactRanges  "0-15, 17, 20-23" for a list of whole numbers (in the given order).
s = "";
if isempty(v)
    return
end
v = v(:)';
parts = strings(0, 1);
i = 1;
while i <= numel(v)
    j = i;
    while j < numel(v) && v(j + 1) == v(j) + 1
        j = j + 1;
    end
    if j > i
        parts(end + 1) = sprintf("%g-%g", v(i), v(j)); %#ok<AGROW>
    else
        parts(end + 1) = sprintf("%g", v(i)); %#ok<AGROW>
    end
    i = j + 1;
end
s = strjoin(parts, ", ");
end
