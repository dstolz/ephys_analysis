function [events, applied] = digitalLinePolarity(events, invertedLines, nSamples, Fs)
%digitalLinePolarity  Apply per-line TTL polarity to a digital-input events struct.
%   [EVENTS, APPLIED] = digitalLinePolarity(EVENTS, INVERTEDLINES, NSAMPLES, Fs)
%   takes the universal events struct (one field per line, [k x 2]
%   [t_on t_off] seconds, t = row/Fs, as every reader returns it: the HIGH
%   runs of each line) and relabels the lines named in INVERTEDLINES.
%
%     normal   (default) a line is on while high: onset = rising edge (first
%              high row), offset = last high row before the falling edge
%     inverted a line is on while low: onset = falling edge (first low row),
%              offset = last low row before the rising edge
%
%   An inverted line's intervals are the complement of its high runs within
%   rows 1..NSAMPLES, so a low stretch at the start or end of the recording
%   counts the same way a high stretch there does for a normal line. Names in
%   INVERTEDLINES that the struct does not have are ignored; APPLIED lists the
%   lines that were inverted.
%
%   See also EphysReader.highSegments, EphysDataset.deriveSignals,
%   pairEpsychTrials.

arguments
    events (1,1) struct
    invertedLines (1,:) string
    nSamples (1,1) double
    Fs (1,1) double {mustBePositive}
end

applied = intersect(invertedLines, string(fieldnames(events)).', 'stable');
if isempty(applied)
    applied = string.empty(1, 0);
    return
end
if ~(isfinite(nSamples) && nSamples > 0)
    error('digitalLinePolarity:NumSamples', 'The recording length (samples) is needed to invert a line.');
end
for ln = applied
    high = double(events.(ln));
    if isempty(high); high = zeros(0, 2); end
    rows = round(high * Fs);
    starts = [1; rows(:, 2) + 1];
    stops  = [rows(:, 1) - 1; nSamples];
    keep = stops >= starts;
    iv = [starts(keep) stops(keep)] / Fs;
    if isempty(iv); iv = zeros(0, 2); end
    events.(ln) = iv;
end
end
