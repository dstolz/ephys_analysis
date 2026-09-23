function [Y, fs, meta] = selectChannels(src, signal, opts)
%selectChannels  One derived signal of a dataset, some or all of its channels.
%   [Y, FS, META] = selectChannels(SRC, SIGNAL, Channels=CH) loads SIGNAL
%   ("LFP" | "MUA" | "SPIKE" | "AUX") of the dataset SRC (loadAnalysisSource)
%   through SRC.outputs -- the extract file holding it, cached when the
%   outputs have CacheData -- and returns
%     Y      [nSamples x nChannels] single, microvolts (AUX: volts); row k
%            is at t = (k-1)/FS
%     FS     its rate, Hz
%     META   table, one row per column of Y: label, channel (1-based column
%            of the signal), shank, x, y (probe position of that amplifier
%            channel, um; NaN when unknown; AUX has none), units ("uV" |
%            "V")
%   CH lists 1-based columns of the signal ([] = all).
%
%   The whole signal is read once per dataset (a MUA at 2 kHz x 64 channels
%   x 1 h is ~1.8 GB in single), so load one signal at a time and clear the
%   outputs' cache between datasets (EphysAnalysisRunner does). With every
%   channel in order (CH [] or 1:nChannels) Y is the cached signal itself,
%   not a copy; only a subset or a new order makes one.
%
%   Errors: selectChannels:NoSignal, selectChannels:BadChannels.
%
%   See also loadAnalysisSource, evokedPotential, DatasetOutputs.

arguments
    src (1,1) struct
    signal (1,1) string
    opts.Channels (1,:) double = []
end

signal = upper(signal);
if ~ismember(signal, DatasetOutputs.SignalTypes)
    error('selectChannels:NoSignal', 'Unknown signal "%s" (expected LFP, MUA, SPIKE or AUX).', signal);
end
if ~src.signals.(signal)
    error('selectChannels:NoSignal', '%s has no %s extract.', src.name, signal);
end
S = src.outputs.load(signal);
Y = S.Y.(signal);
I = S.info.(signal);
fs = double(I.Fs);
nCh = size(Y, 2);
ch = opts.Channels;
if isempty(ch); ch = 1:nCh; end
if any(ch < 1 | ch > nCh | ch ~= round(ch))
    error('selectChannels:BadChannels', '%s %s has %d channel(s); Channels asks for %s.', ...
        src.name, signal, nCh, mat2str(ch));
end
if ~isequal(ch, 1:nCh)
    Y = Y(:, ch);   % indexing copies: only for a real subset or reorder
end
if signal == "AUX"
    labels = strings(nCh, 1);
    if isfield(I, 'labels'); labels = reshape(string(I.labels), [], 1); end
    units = "V";
    shank = zeros(numel(ch), 1); x = NaN(numel(ch), 1); y = NaN(numel(ch), 1);
    recCh = NaN(numel(ch), 1);
else
    labels = src.labels;
    if isfield(S, 'info') && isfield(S.info, 'labels'); labels = reshape(string(S.info.labels), [], 1); end
    units = "uV";
    rec = recordingChannels(S.info, nCh);
    recCh = rec(ch);
    [shank, x, y] = probeSites(src.probe, recCh);
end
if numel(labels) < nCh; labels(end+1:nCh, 1) = "ch" + (numel(labels)+1:nCh).'; end
label = labels(ch);
label(label == "") = "ch" + ch(label == "").';
channel = ch(:);
meta = table(label(:), channel, recCh(:), shank, x, y, repmat(units, numel(ch), 1), ...
    'VariableNames', {'label', 'channel', 'recordingChannel', 'shank', 'x', 'y', 'units'});
end


function rec = recordingChannels(info, nCh)
%recordingChannels  1-based amplifier channel of each extract column.
%   Column c is keepAmpChannels(channelRemap(c)) (deriveSignals' order of
%   operations); without either option it is channel c.
rec = (1:nCh).';
if ~isfield(info, 'importOptions') || ~isstruct(info.importOptions); return; end
o = info.importOptions;
k = []; r = [];
if isfield(o, 'keepAmpChannels'); k = double(o.keepAmpChannels(:)); end
if isfield(o, 'channelRemap');    r = double(o.channelRemap(:)); end
if isempty(k); k = (1:max([nCh; r])).'; end
if isempty(r); r = (1:numel(k)).'; end
if numel(r) == nCh && all(r >= 1 & r <= numel(k))
    rec = k(r);
end
end
