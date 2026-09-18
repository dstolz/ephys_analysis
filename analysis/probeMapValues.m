function R = probeMapValues(T, probe, opts)
%probeMapValues  One value per probe site, ready for renderProbeMap.
%   R = probeMapValues(T, PROBE, Value="rate") spreads the unitSummary table
%   T over the sites of the probe map PROBE (chanMap 0-based, xc, yc,
%   kcoords): each site takes the rows of T on its recording channel
%   (chanMap + 1) and shows
%     "rate"     the summed rate, Hz (NaN where T has no row)
%     "nSpikes"  the summed spike count (NaN where T has no row)
%     "nUnits"   how many rows (units) sit there (0 where none)
%
%   R fields: kind "probemap", channel, x, y, shank (one per site), value,
%   valueName, units ("Hz" | "spikes" | "units"), unitX / unitY (T.x / T.y,
%   the units' own positions), table (T), labels (site labels "ch<N>"),
%   groups (one "all" row), n (rows of T), params, created.
%   Error: probeMapValues:NoProbe.
%
%   See also unitSummary, renderProbeMap.

arguments
    T table
    probe
    opts.Value (1,1) string {mustBeMember(opts.Value, ["rate" "nSpikes" "nUnits"])} = "rate"
end

if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'xc', 'yc'}))
    error('probeMapValues:NoProbe', 'A probe map (chanMap, xc, yc) is needed to draw values on the probe.');
end
channel = double(probe.chanMap(:)) + 1;
n = numel(channel);
x = double(probe.xc(:)); y = double(probe.yc(:));
x = x(1:n); y = y(1:n);
shank = zeros(n, 1);
if isfield(probe, 'kcoords'); k = double(probe.kcoords(:)); shank = k(1:n); end
value = NaN(n, 1);
if opts.Value == "nUnits"; value(:) = 0; end
for s = 1:n
    rows = T.channel == channel(s);
    if ~any(rows); continue; end
    switch opts.Value
        case "rate",    value(s) = sum(T.rateHz(rows), 'omitnan');
        case "nSpikes", value(s) = sum(T.nSpikes(rows));
        case "nUnits",  value(s) = nnz(rows);
    end
end

R = struct();
R.kind = "probemap";
R.channel = channel;
R.x = x;
R.y = y;
R.shank = shank;
R.value = value;
R.valueName = opts.Value;
switch opts.Value
    case "rate",    R.units = "Hz";
    case "nSpikes", R.units = "spikes";
    case "nUnits",  R.units = "units";
end
R.unitX = T.x;
R.unitY = T.y;
R.table = T;
R.labels = "ch" + channel;
R.groups = table(1, "all", [0.15 0.15 0.15], height(T), 'VariableNames', {'index', 'label', 'color', 'n'});
R.n = height(T);
R.params = struct('Value', opts.Value);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
