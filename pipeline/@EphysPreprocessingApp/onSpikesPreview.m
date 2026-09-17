function onSpikesPreview(obj)
%onSpikesPreview  Detect on the first seconds of the Dataset-menu dataset.
%   Uses the Spikes-tab settings on a single in-memory block (no streaming
%   options), and lists per-channel thresholds, counts and rates.
d = obj.currentVizDataset();
if isempty(d)
    uialert(obj.Fig, "Pick a dataset in the Dataset menu first.", "Spikes preview");
    return
end
if isnan(d.Fs) || isempty(d.PerFile); d.refreshMetadata(); end
K = obj.gatherSpikesSection();
secs = obj.SpkPreviewSecondsField.Value;
nWant = max(1, round(secs * d.Fs));
obj.SpkPreviewButton.Enable = "off";
cleanup = onCleanup(@() set(obj.SpkPreviewButton, "Enable", "on"));
obj.SpkPreviewLabel.Text = "Reading...";
drawnow;
try
    if d.supportsRandomAccess()
        X = d.readWindowUV(0, nWant);
    else
        plan = d.streamPlan();
        if isempty(plan); error('No recording files.'); end
        X = d.readChunkUV(plan(1));
        X = X(1:min(nWant, end), :);
    end
    ch = EphysPipelineConfig.spikeChannels(K, d);
    if isempty(ch); ch = 1:size(X, 2); end
    X = X(:, ch);
    dopt = EphysPipelineConfig.detectOptions(K);
    for f = ["MaxChunkSamples" "EdgePadMs"]
        if isfield(dopt, f); dopt = rmfield(dopt, f); end
    end
    dopt.Waveforms = false;
    args = namedargs2cell(dopt);
    [ts, ~, info] = d.detectSpikes(X, args{:});
    nS = size(X, 1);
    thr = nan(1, numel(ts));
    if isfield(info, 'threshold') && ~isempty(info.threshold)
        thr = double(info.threshold(1, :));
    end
    counts = cellfun(@numel, ts);
    names = strings(1, numel(ch));
    okName = ch <= numel(d.ChannelNames);
    names(okName) = d.ChannelNames(ch(okName));
    C = cell(numel(ch), 5);
    for c = 1:numel(ch)
        C(c, :) = {ch(c), char(names(c)), round(thr(min(c, numel(thr))), 1), counts(c), round(counts(c) / (nS / d.Fs), 2)};
    end
    obj.SpkPreviewTable.Data = C;
    obj.SpkPreviewLabel.Text = sprintf("%s: %.2f s, %d channel(s), %d event(s) (%s, %s).", d.Name, nS / d.Fs, ...
        numel(ch), sum(counts), K.ThresholdMethod, K.Polarity);
catch ME
    obj.SpkPreviewLabel.Text = "Preview failed: " + string(ME.message);
end
end
