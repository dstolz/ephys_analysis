function s = chronuxTimeSummary(TB)
%chronuxTimeSummary  A chronuxTimeBase without its per-trial vectors, as a result keeps it.
s = rmfield(TB, intersect(["starts" "groupIndex" "runRows"], string(fieldnames(TB))));
end
