function sorter = sorterOfSort(folder)
%sorterOfSort  The sorter that wrote the sorted output in FOLDER.
%   The "sorter" runSpikeInterface writes in the run's settings.json, else
%   the run folder's name (EphysDataset.sorterOfRunDir: si_<sorter>, any
%   other folder Kilosort4's). EphysDataset.sorterLabel names it.
S = readJsonFile(fullfile(char(folder), 'settings.json'), ErrorOnFail=false);
if isstruct(S) && isfield(S, 'sorter') && EphysDataset.isSpikeInterfaceSorter(string(S.sorter))
    sorter = string(S.sorter);
else
    sorter = EphysDataset.sorterOfRunDir(folder);
end
end
