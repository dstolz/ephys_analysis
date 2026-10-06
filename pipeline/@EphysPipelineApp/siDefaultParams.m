function txt = siDefaultParams(obj, sorter)
%siDefaultParams  SORTER's default parameters as JSON text, as SpikeInterface gives them.
%   From the sorters "Find SpikeInterface sorters" found (SISorters); ""
%   when SORTER is not among them.
%
%   See also onFindSorters, EphysDataset.spikeInterfaceSorters.
txt = "";
if isempty(obj.SISorters); return; end
k = find([obj.SISorters.name] == string(sorter), 1);
if ~isempty(k)
    txt = string(obj.SISorters(k).params);
end
end
