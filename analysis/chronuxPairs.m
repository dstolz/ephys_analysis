function P = chronuxPairs(S, channels, labels)
%chronuxPairs  The channel pairs a coherence analysis takes, from its settings.
%   P = chronuxPairs(S, CHANNELS, LABELS): S chronuxSettings; CHANNELS the
%   signal's columns at hand (a block's D.channels) and LABELS their
%   labels. pairMode "pair": S.seed with S.partner. "seed": S.seed with
%   every other channel of S.channels (all of CHANNELS when empty), in
%   that order. P is a table: a, b (the signal's columns), labelA, labelB,
%   label ("labelA-labelB"). Errors chronuxPairs:BadPair when a channel is
%   not at hand, the pair is a channel with itself, or no pair is left.
%
%   See also chronuxCoherence, chronuxSettings.
channels = reshape(double(channels), 1, []);
labels = reshape(string(labels), 1, []);
seed = S.seed;
if S.pairMode == "pair"
    others = S.partner;
else
    others = S.channels;
    if isempty(others); others = channels; end
    others = others(others ~= seed);
end
need = [seed others];
if any(~ismember(need, channels))
    error('chronuxPairs:BadPair', 'Channel(s) %s of the pairs are not among those read.', ...
        strjoin(string(need(~ismember(need, channels))), ", "));
end
if isempty(others) || any(others == seed)
    error('chronuxPairs:BadPair', 'The coherence needs two different channels: pick a partner other than the seed.');
end
n = numel(others);
a = repmat(seed, n, 1);
b = others(:);
name = @(c) labels(arrayfun(@(x) find(channels == x, 1), c));
labelA = reshape(name(a), [], 1);
labelB = reshape(name(b), [], 1);
P = table(a, b, labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'b', 'labelA', 'labelB', 'label'});
end
