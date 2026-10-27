function R = probeMapValues(T, probe, opts)
%probeMapValues  The unitSummary table's values on the probe, ready for renderProbeMap.
%   R = probeMapValues(T, PROBE, Value="rate") places the unitSummary table
%   T on the sites of the probe map PROBE (chanMap 0-based, xc, yc,
%   kcoords). A unit's value is its own, drawn on the unit:
%     "rate"     its rate, Hz
%     "nSpikes"  its spike count
%   and a count is the site's, drawn on the site:
%     "nUnits"   how many rows (units) sit on its recording channel
%                (chanMap + 1; 0 where none)
%
%   R fields: kind "probemap", channel, x, y, shank (one per site), on
%   ("units" | "sites": what value is one per), value (one per row of T,
%   or one per site), valueName, units ("Hz" | "spikes" | "units"),
%   unitX / unitY (T.x / T.y, the units' own positions; a unit without
%   one at the site of its channel), table (T), labels (site labels
%   "ch<N>"), groups (one "all" row), n (rows of T), params, created.
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
switch opts.Value
    case "rate",    value = double(T.rateHz(:));
    case "nSpikes", value = double(T.nSpikes(:));
    case "nUnits",  value = arrayfun(@(c) nnz(T.channel == c), channel);
end
unitX = double(T.x(:));
unitY = double(T.y(:));
[at, k] = ismember(double(T.channel(:)), channel);
none = ~(isfinite(unitX) & isfinite(unitY)) & at;   % no position of its own: its channel's site
unitX(none) = x(k(none));
unitY(none) = y(k(none));

R = struct();
R.kind = "probemap";
R.channel = channel;
R.x = x;
R.y = y;
R.shank = shank;
R.on = "units";
if opts.Value == "nUnits"; R.on = "sites"; end
R.value = value;
R.valueName = opts.Value;
switch opts.Value
    case "rate",    R.units = "Hz";
    case "nSpikes", R.units = "spikes";
    case "nUnits",  R.units = "units";
end
R.unitX = unitX;
R.unitY = unitY;
R.table = T;
R.labels = "ch" + channel;
R.groups = table(1, "all", [0.15 0.15 0.15], height(T), 'VariableNames', {'index', 'label', 'color', 'n'});
R.n = height(T);
R.params = struct('Value', opts.Value);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
