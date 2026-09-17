function [units, info] = readSortedUnits(obj, opts)
%readSortedUnits  Sorted units associated with this dataset.
%   [UNITS, INFO] = ds.readSortedUnits() reads the Kilosort4 / phy output in
%   ds.sortingResultsDir() (an explicit SortingDir, else the auto-discovered
%   kilosortResultsDir) through EphysDataset.readPhyUnits, with the dataset's
%   own defaults: the recording rate as the sample-rate fallback, its native
%   channel names and probe file for the SpikeInterface channel mapping, and
%   its unitIdentity, so every unit is labelled with the subject and
%   recording start ("su042_1255_260908T1039") and carries datasetKey.
%   The identity is checked first: a Name that does not match NamePattern
%   throws EphysDataset:unitIdentity:* before any sorter output is read.
%
%   Options: ResultsDir (override the folder), and every readPhyUnits option
%   (Groups, IncludeNoise, Templates, FullTemplates, ChannelMap, FsFallback).
%
%   See also EphysDataset.readPhyUnits, EphysDataset.unitIdentity,
%   EphysDataset.sortingResultsDir,
%   EphysDataset.spikesToMat, ChronuxDataset.spikes.

arguments
    obj (1,1) EphysDataset
    opts.ResultsDir (1,1) string = ""
    opts.Groups (1,:) string = string.empty(1,0)
    opts.IncludeNoise (1,1) logical = false
    opts.Templates (1,1) logical = true
    opts.FullTemplates (1,1) logical = false
    opts.ChannelMap (1,:) double = []
    opts.FsFallback (1,1) double = NaN
end

identity = obj.unitIdentity();
dir0 = opts.ResultsDir;
if dir0 == ""
    dir0 = string(obj.sortingResultsDir());
end
fsFallback = opts.FsFallback;
if isnan(fsFallback); fsFallback = obj.Fs; end

[units, info] = EphysDataset.readPhyUnits(dir0, ...
    Groups=opts.Groups, IncludeNoise=opts.IncludeNoise, ...
    Templates=opts.Templates, FullTemplates=opts.FullTemplates, ...
    ChannelMap=opts.ChannelMap, ChannelNames=obj.NativeNames, ...
    ProbeFile=obj.ProbeFile, FsFallback=fsFallback, Identity=identity);
end
