function [units, Q] = unitQuality(obj, units, info, opts)
%unitQuality  Add quality metrics to this dataset's sorted units.
%   [UNITS, Q] = ds.unitQuality() reads the sorted units (readSortedUnits)
%   and adds, per unit, the metrics of unitQualityMetrics (SpikeInterface's
%   definitions) through EphysDataset.unitQualityOf: firingRate,
%   isiViolationsRatio, isiViolationsCount, presenceRatio, amplitudeCutoff,
%   snr, driftPtp, driftStd, driftMad as column fields of UNITS, and
%   UNITS.quality. Q is the same as a table (unitId first).
%   [UNITS, Q] = ds.unitQuality(UNITS, INFO) takes what readSortedUnits /
%   readPhyUnits returned instead of reading it.
%
%   What the dataset adds to unitQualityOf:
%     length   the samples the sort covered: its .bin's (settings.json
%              filename, n_chan_bin, data_dtype) when the .bin is there,
%              else the recording's (NumSamples)
%     noise    for SNR: noiseLevels of the recording high-passed at
%              settings.json's highpass_cutoff (300 Hz) with a 3rd-order
%              filter, as Kilosort4 filters, its common reference applied
%              as the dataset reads it, over 4 chunks spread over the
%              recording; measured once per channel and kept in the
%              sort's quality_metrics.json
%
%   Options
%     ResultsDir   the sort to read ("" = sortingResultsDir)
%     Cache        true: read and write quality_metrics.json
%     Noise        true: measure the recording's noise for SNR (false:
%                  snr NaN and nothing read from the recording)
%     Metrics      struct of unitQualityMetrics options (IsiThresholdMs,
%                  PresenceBinS, AmplitudeBins, DriftIntervalS, ...)
%
%   See also EphysDataset.unitQualityOf, unitQualityMetrics, unitQualityPass,
%   EphysDataset.readSortedUnits, writeUnitQualityReport.

arguments
    obj (1,1) EphysDataset
    units = []
    info = []
    opts.ResultsDir (1,1) string = ""
    opts.Cache (1,1) logical = true
    opts.Noise (1,1) logical = true
    opts.Metrics (1,1) struct = struct()
end

if isempty(units)
    [units, info] = obj.readSortedUnits(ResultsDir=opts.ResultsDir);
elseif isempty(info)
    error('EphysDataset:unitQuality:NoInfo', ...
        'Pass the INFO readSortedUnits / readPhyUnits returned with the units (it holds the per-spike arrays).');
end
dir0 = string(units.resultsDir);
[nSamp, source] = sortedSamples(obj, dir0);
noiseFcn = [];
if opts.Noise
    hp = readHighpass(dir0);
    noiseFcn = @(ch) getfield(obj.noiseLevels(Filter=true, FilterType="highpass", FilterCutoff=hp, ...
        FilterOrder=3, ChannelOrder=ch, MaxChunks=4), 'sigma');
end
[units, Q] = EphysDataset.unitQualityOf(units, info, NumSamples=nSamp, NumSamplesSource=source, ...
    NoiseFcn=noiseFcn, Cache=opts.Cache, Metrics=opts.Metrics);
end


function [n, source] = sortedSamples(obj, dir0)
%sortedSamples  Samples the sort covered: its .bin's, else the recording's.
n = NaN; source = "";
cfg = readJsonFile(fullfile(dir0, 'settings.json'), ErrorOnFail=false);
if isstruct(cfg) && all(isfield(cfg, {'filename', 'n_chan_bin'}))
    f = string(cfg.filename);
    bytes = 2;
    if isfield(cfg, 'data_dtype')
        switch string(cfg.data_dtype)
            case {"int16", "uint16"}, bytes = 2;
            case {"float32", "int32", "uint32"}, bytes = 4;
            case {"float64", "int64"}, bytes = 8;
        end
    end
    d = dir(f);
    if isscalar(d) && ~d.isdir && cfg.n_chan_bin > 0
        n = d.bytes / (bytes * double(cfg.n_chan_bin));
        source = "the sorted .bin (" + f + ")";
        if n == round(n); return; end
        n = NaN;
    end
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
n = obj.NumSamples;
source = "the recording (NumSamples)";
if ~(n > 0)
    error('EphysDataset:unitQuality:NoLength', ...
        'The length of the sorted recording is unknown (no .bin, no recording metadata for %s).', obj.Folder);
end
end


function hp = readHighpass(dir0)
%readHighpass  Kilosort4's high-pass cut-off for this sort (settings.json), else its default 300 Hz.
hp = 300;
cfg = readJsonFile(fullfile(dir0, 'settings.json'), ErrorOnFail=false);
if isstruct(cfg) && isfield(cfg, 'highpass_cutoff') && isnumeric(cfg.highpass_cutoff) ...
        && isscalar(cfg.highpass_cutoff) && cfg.highpass_cutoff > 0
    hp = double(cfg.highpass_cutoff);
end
end


