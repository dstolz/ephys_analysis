function [R, notes] = legacyLooks(R)
%legacyLooks  A version-1 plot's or session plot's looks for a figure: aux roles renamed, retired roles dropped.
%   [R, NOTES] = legacyLooks(R) takes PlotAesthetics rules and returns them
%   for a figure: auxTrace -> trace, auxSem -> sem, auxAxes -> axes (the
%   aux panel is the only trace-drawing panel of a psth / raster figure;
%   the rule then reaches every component of that role in the figure),
%   each with a note; a rule on auxImage, auxGroup, auxScale,
%   behaviorMean, swarm or violin (drawn by no figure) is dropped with the
%   note "look on <role> dropped: figures do not draw it". NOTES is a
%   string row. Nothing but legacyPlotToFigure and legacyMigrate uses it.
%
%   See also legacyPlotToFigure, legacyMigrate, PlotAesthetics.roles.

notes = string.empty(1, 0);
if isempty(R); return; end
renamed = struct('auxTrace', "trace", 'auxSem', "sem", 'auxAxes', "axes");
retired = ["auxImage" "auxGroup" "auxScale" "behaviorMean" "swarm" "violin"];
keep = true(1, numel(R));
for q = 1:numel(R)
    role = string(R(q).role);
    if isfield(renamed, role)
        R(q).role = renamed.(role);
        notes(end+1) = sprintf("The look on %s now applies to %s: the aux signal is a continuous panel of the figure.", ...
            role, renamed.(role)); %#ok<AGROW>
    elseif ismember(role, retired)
        keep(q) = false;
        notes(end+1) = sprintf("look on %s dropped: figures do not draw it", role); %#ok<AGROW>
    end
end
R = R(keep);
end
