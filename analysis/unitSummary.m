function T = unitSummary(src, opts)
%unitSummary  Spike counts and mean rates of a dataset's units or channels.
%   T = unitSummary(SRC, Source="units", Units=USEL) returns one row per
%   sorted unit ("units") or detection channel ("detected") of the dataset
%   SRC (loadAnalysisSource), chosen by the unit selection USEL (see
%   selectUnits): label, class, channel, shank, x, y, nSpikes and rateHz =
%   nSpikes / SRC.durationSec -- the recording's length, not the time of
%   the last spike (NaN when the duration is unknown).
%
%   See also selectUnits, probeMapValues, reportSummaryTables.

arguments
    src (1,1) struct
    opts.Source (1,1) string {mustBeMember(opts.Source, ["units" "detected"])} = "units"
    opts.Units = []
end

usel = opts.Units;
if isempty(usel); usel = struct(); end
usel.source = opts.Source;
[st, meta] = selectUnits(src, usel);
T = meta(:, {'label', 'class', 'channel', 'shank', 'x', 'y'});
T.nSpikes = cellfun(@numel, st);
T.rateHz = T.nSpikes / src.durationSec;
end
