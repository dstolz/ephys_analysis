function t = sortersLabel(dirs, sorter)
%sortersLabel  What sorts the runs whose results folders are DIRS.
%   "Kilosort4", or "<sorter> (SpikeInterface)", when every run is that
%   sorter's (by its folder's name: EphysDataset.sorterOfRunDir), else
%   "sorting". With no folder, SORTER's label (default "sorting").
%
%   See also EphysDataset.sorterLabel.
dirs = string(dirs);
if isempty(dirs)
    if nargin < 2; t = "sorting"; else; t = EphysDataset.sorterLabel(sorter); end
    return
end
who = unique(arrayfun(@(f) EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(f)), dirs));
if isscalar(who)
    t = who;
else
    t = "sorting";
end
end
