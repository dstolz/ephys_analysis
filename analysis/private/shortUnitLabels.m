function labels = shortUnitLabels(labels)
%shortUnitLabels  Unit labels without the recording suffix they all share.
%   Sorted units are labelled "<class><id>_<suffix>" (readPhyUnits), and the
%   units of one recording share the suffix, so tick labels and tile titles
%   keep only the part before the first "_". Labels are returned unchanged
%   when any has no "_" or the suffixes differ (units from several recordings).
labels = string(labels);
if isempty(labels) || ~all(contains(labels, "_") & ~startsWith(labels, "_"), "all"); return; end
if numel(unique(extractAfter(labels, "_"))) > 1; return; end
labels = extractBefore(labels, "_");
end
