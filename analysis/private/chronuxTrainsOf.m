function SP = chronuxTrainsOf(st, meta, source, labels)
%chronuxTrainsOf  Spike trains (selectUnits' output) as the trains the Chronux spike analyses take.
%   SP = chronuxTrainsOf(ST, META, SOURCE, LABELS): ST {nU x 1} spike
%   times on the continuous clock (selectUnits), META their table, SOURCE
%   "units" or "detected" and LABELS their names (default META.label). SP
%   has chronuxSpikeTrains' fields: times (a 1 x nU struct array with field
%   times), labels, index = 1:nU (the trains' places in SP: what
%   S.unitSeed and S.unitPartner name), unitId (META.unitId), class and
%   source.
%
%   See also chronuxSpikeTrains, selectUnits, computeSpectrumPanel.
nU = numel(st);
if nargin < 4 || isempty(labels)
    labels = string(meta.label);
end
times = struct('times', cell(1, nU));
for u = 1:nU
    times(u).times = double(st{u}(:));
end
cls = repmat("", 1, nU);
ids = NaN(1, nU);
if istable(meta) && height(meta) == nU
    v = string(meta.Properties.VariableNames);
    if ismember("class", v); cls = reshape(string(meta.class), 1, []); end
    if ismember("unitId", v); ids = reshape(double(meta.unitId), 1, []); end
end
SP = struct('times', times, 'labels', reshape(string(labels), 1, []), 'index', 1:nU, 'unitId', ids, ...
    'class', cls, 'source', string(source));
end
