function refreshSorterItems(obj, want)
%refreshSorterItems  Fill the Sorter drop-down: Kilosort4, then the SpikeInterface sorters.
%   The SpikeInterface sorters are the ones "Find SpikeInterface sorters"
%   last found (SISorters; read from the preference SISorters when the app
%   has none yet), less kilosort4, which the pipeline runs itself. The
%   sorter the config names (WANT, default the working config's) stays in
%   the list even when it was not found (marked so).
%
%   See also onFindSorters, showSorterControls.
if isempty(obj.SortSorterDropDown) || ~isvalid(obj.SortSorterDropDown); return; end
if isempty(obj.SISorters)
    try
        if AppPrefs.ispref(obj.PrefGroup, 'SISorters')
            c = AppPrefs.getpref(obj.PrefGroup, 'SISorters');
            obj.SISorters = c.sorters;
            obj.SIVersion = string(c.spikeinterface);
        end
    catch
        % an unreadable cache is a list not found yet
    end
end
names = string.empty(1, 0);
if ~isempty(obj.SISorters)
    names = [obj.SISorters.name];
    names = names(EphysDataset.isSpikeInterfaceSorter(names));
end
items = "Kilosort4";
data = "kilosort4";
for n = names
    items(end+1) = n + " (SpikeInterface)"; %#ok<AGROW>
    data(end+1) = n; %#ok<AGROW>
end
if nargin < 2; want = obj.Config.Sorting.Sorter; end
want = string(want);
if ~ismember(want, data)
    items(end+1) = want + " (SpikeInterface, not found: Find SpikeInterface sorters)";
    data(end+1) = want;
end
cur = string(obj.SortSorterDropDown.Value);
obj.SortSorterDropDown.Items = cellstr(items);
obj.SortSorterDropDown.ItemsData = cellstr(data);
if ismember(cur, data)
    obj.SortSorterDropDown.Value = char(cur);
else
    obj.SortSorterDropDown.Value = char(want);
end
end
