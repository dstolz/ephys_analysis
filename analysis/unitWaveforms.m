function W = unitWaveforms(src, meta, opts)
%unitWaveforms  Each unit's spike waveform on its peak channel, for a plot's waveform boxes.
%   W = unitWaveforms(SRC, META, Source=, MaxSpikes=, Check=) takes the dataset SRC
%   (loadAnalysisSource) and the units META (selectUnits' table, one row
%   per unit, in the plot's order) and gives each unit's waveform:
%     Source "units" (sorted units, by META.unitId): at most MaxSpikes of
%       the unit's spikes, picked at random (the same ones each time), cut
%       on its peak channel from the data the sort read and prepared as
%       Kilosort4 saw them (DatasetOutputs.readWaveforms,
%       EphysDataset.readPhyWaveforms), and their mean. When they cannot be
%       read (the sorted .bin is not there) the unit's template
%       (units.templateWaveform) is its mean, with no spikes; the warning
%       unitWaveforms:Templates and W.note say why.
%     Source "detected" (a channel's threshold detections, by
%       META.unitId = the channel): the waveforms the spikes file keeps
%       (the Spikes step's Waveforms option), MaxSpikes of them at random,
%       and the mean of them all. A spikes file without waveforms gives
%       none: the warning unitWaveforms:NoWaveforms and W.note say so.
%   With SRC.outputs' CacheData (loadAnalysisSource's) the spikes are read
%   once per unit and count, so a redraw does not read them again. Check is
%   a function handle called with no input before each unit (default []); it
%   may throw to stop (the app's Cancel button).
%
%   W fields (one row per unit of META)
%     timeMs     {nU x 1} [nt x 1] ms from the spike (0 = its sample)
%     mean       {nU x 1} [nt x 1] the mean waveform ([] when none)
%     spikes     {nU x 1} [nt x k] the spikes, k <= MaxSpikes ([] for a
%                template, or none)
%     from       [nU x 1] "spikes" | "template" | "none"
%     units      [nU x 1] what the values are: "uV", "bin" (the sorted
%                .bin's units), "whitened" (see readPhyWaveforms), "" (none)
%     total      [nU x 1] the unit's spikes in the whole recording (0 for none),
%                however few of them are drawn
%     note       "" or why some units have no spikes
%     maxSpikes  MaxSpikes
%
%   See also selectUnits, DatasetOutputs.readWaveforms,
%   EphysDataset.readPhyWaveforms, renderPSTH, renderRaster, renderTuning.

arguments
    src (1,1) struct
    meta table
    opts.Source (1,1) string {mustBeMember(opts.Source, ["units" "detected"])} = "units"
    opts.MaxSpikes (1,1) double {mustBePositive, mustBeInteger} = 100
    opts.Check = []
end

nU = height(meta);
W = struct('timeMs', {cell(nU, 1)}, 'mean', {cell(nU, 1)}, 'spikes', {cell(nU, 1)}, ...
    'from', repmat("none", nU, 1), 'units', strings(nU, 1), 'total', zeros(nU, 1), 'note', "", ...
    'maxSpikes', opts.MaxSpikes);
if nU == 0; return; end
out = src.outputs;
switch opts.Source
    case "units"
        U = out.load("sorting");
        unread = "";                       % why the sorted data cannot be read: templates from then on
        for u = 1:nU
            if ~isempty(opts.Check); opts.Check(); end
            id = double(meta.unitId(u));
            if unread == ""
                try
                    [w, info] = out.readWaveforms(id, MaxSpikes=opts.MaxSpikes);
                    if size(w, 2) > 0
                        W.spikes{u} = w;
                        W.mean{u} = mean(w, 2);
                        W.timeMs{u} = double(info.timeMs(:));
                        W.from(u) = "spikes";
                        W.units(u) = string(info.units);
                        row = find(double(U.unitId) == id, 1);
                        W.total(u) = numel(U.samples{row});
                        continue
                    end
                catch ME
                    if ~startsWith(ME.identifier, ["EphysDataset:readPhyWaveforms:" "DatasetOutputs:NoUnit"])
                        rethrow(ME);
                    end
                    if ~ismember(ME.identifier, ["EphysDataset:readPhyWaveforms:BadChannels" "DatasetOutputs:NoUnit"])
                        unread = string(ME.message);
                    end
                end
            end
            row = find(double(U.unitId) == id, 1);
            if ~isempty(row) && isfield(U, 'templateWaveform') && ~isempty(U.templateWaveform{row})
                W.mean{u} = double(U.templateWaveform{row}(:));
                W.timeMs{u} = double(U.templateTimeMs(:));
                W.from(u) = "template";
                W.units(u) = string(U.templateUnits);
            end
        end
        if unread ~= ""
            W.note = "The sorted spikes cannot be read, so the units' templates are drawn: " + unread;
            warning('unitWaveforms:Templates', '%s: %s', src.name, W.note);
        end
    case "detected"
        S = out.load("spikes", "detected");
        D = S.detected;
        if ~isfield(D, 'wf') || isempty(D.wf) || ~isfield(D.info, 'waveformTimeMs')
            W.note = "The spikes file keeps no waveforms (the Spikes step ran without its Waveforms option).";
            warning('unitWaveforms:NoWaveforms', '%s: %s', src.name, W.note);
            return
        end
        tms = double(D.info.waveformTimeMs(:));
        ch = double(D.channels(:));
        for u = 1:nU
            k = find(ch == double(meta.unitId(u)), 1);
            if isempty(k) || k > numel(D.wf) || isempty(D.wf{k}); continue; end
            w = double(D.wf{k}).';         % [nWin x nSpikes]
            W.mean{u} = mean(w, 2);
            n = size(w, 2);
            if n > opts.MaxSpikes
                pick = sort(randperm(RandStream('mt19937ar', 'Seed', 0), n, opts.MaxSpikes));
                w = w(:, pick);
            end
            W.spikes{u} = w;
            W.timeMs{u} = tms;
            W.from(u) = "spikes";
            W.units(u) = "uV";
            W.total(u) = n;
        end
end
end
