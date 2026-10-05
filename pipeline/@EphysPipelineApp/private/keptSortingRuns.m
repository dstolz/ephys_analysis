function runs = keptSortingRuns(group)
%keptSortingRuns  The Kilosort4 runs going when the app last closed (preference KeptSortingRuns).
%   RUNS is a 1 x N struct array in KSRuns' shape (EphysPipeline.emptyRuns),
%   empty when nothing is kept, or the preference is not of that shape.
%
%   See also keepKSRuns, followKeptKSRuns.
runs = EphysPipeline.emptyRuns();
if ~AppPrefs.ispref(group, 'KeptSortingRuns'); return; end
v = AppPrefs.getpref(group, 'KeptSortingRuns');
if isstruct(v) && isequal(fieldnames(v), fieldnames(runs))
    runs = reshape(v, 1, []);
end
end
