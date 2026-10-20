function T = unitSummary(src, opts)
%unitSummary  Spike counts and mean rates of a dataset's units or channels.
%   T = unitSummary(SRC, Source="units", Units=USEL) returns one row per
%   sorted unit ("units") or detection channel ("detected") of the dataset
%   SRC (loadAnalysisSource), chosen by the unit selection USEL (see
%   selectUnits): label, class, channel, shank, x, y, nSpikes and rateHz =
%   nSpikes / SRC.durationSec -- the recording's length, not the time of
%   the last spike (NaN when the duration is unknown) -- and starred: the
%   unit's star on the sort in use, a detection channel's its channel's
%   star (DatasetFavorites: <Name>_favorites.json in the output folder;
%   false without it). Ref and Selection are selectUnits' options: the
%   events of a response test in USEL.
%
%   See also selectUnits, probeMapValues, reportSummaryTables,
%   DatasetFavorites.

arguments
    src (1,1) struct
    opts.Source (1,1) string {mustBeMember(opts.Source, ["units" "detected"])} = "units"
    opts.Units = []
    opts.Ref = []
    opts.Selection = []
end

usel = opts.Units;
if isempty(usel); usel = struct(); end
usel.source = opts.Source;
[st, meta] = selectUnits(src, usel, Ref=opts.Ref, Selection=opts.Selection);
T = meta(:, {'label', 'class', 'channel', 'shank', 'x', 'y'});
T.nSpikes = cellfun(@numel, st);
T.rateHz = T.nSpikes / src.durationSec;
T.starred = false(height(T), 1);
try
    fav = DatasetFavorites(src);
    if opts.Source == "detected"
        T.starred = reshape(fav.isStarred("channel", double(meta.channel)), [], 1);
    else
        T.starred = reshape(fav.isStarred("unit", double(meta.unitId)), [], 1);
    end
catch   % a source without outputs: no star
end
end
