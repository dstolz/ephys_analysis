function D = chronuxBlockOf(Y, fs, meta, signal, labels)
%chronuxBlockOf  A signal's columns (selectChannels' output) as the block the Chronux analyses take.
%   D = chronuxBlockOf(Y, FS, META, SIGNAL, LABELS): Y [nSamples x n] the
%   columns read (row k at (k-1)/FS on the continuous clock, the whole
%   recording), FS the rate, META their rows of selectChannels' META (units),
%   SIGNAL the extract ("LFP", ...) and LABELS their names (default
%   META.label). D has loadChronuxExport's fields that chronuxSpectrum,
%   chronuxSpecgram, chronuxCoherence and chronuxSpikeField use: signal,
%   data (Y), fs, row0 = 1 (the block starts at the recording's first row),
%   channels = 1:n (the columns' places in D: what S.seed, S.partner,
%   S.channels and S.fieldChannel name), labels and units (META.units(1),
%   "uV" when it has none).
%
%   See also loadChronuxExport, selectChannels, computeSpectrumPanel.
if nargin < 5 || isempty(labels)
    labels = string(meta.label);
end
units = "uV";
if istable(meta) && ismember("units", string(meta.Properties.VariableNames)) && height(meta) > 0
    units = string(meta.units(1));
end
D = struct('signal', string(signal), 'data', Y, 'fs', double(fs), 'row0', 1, 'channels', 1:size(Y, 2), ...
    'labels', reshape(string(labels), 1, []), 'units', units);
end
