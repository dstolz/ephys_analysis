function [E, G] = figureEpochs(src, spec)
%figureEpochs  A figure's own epochs and trial groups, as figureCompute aligns them.
%   [E, G] = figureEpochs(SRC, SPEC) for the figure SPEC
%   (EphysAnalysisConfig.figureFor) on the dataset SRC (loadAnalysisSource)
%   is epochTable(SRC, SPEC.ref, Window=SPEC.window,
%   Selection=SPEC.selection, Baseline=, Columns=) with the inputs
%   figureCompute gives it: the hull of the baseline windows of the panels
%   on the figure's alignment (an epoch whose baseline leaves the
%   recording is dropped) and their rasters' sort and tuning curves'
%   parameters (copied onto E). So E holds the epochs the figure preview
%   draws, every trial group of them: a per-group observation
%   (observe.perGroup) keeps one group's rows (E.groupIndex). A panel with
%   its own ref, window or selection has epochs of its own (figureCompute's
%   F.panels(k).epochs), not these. A figure with no aligned panel gets
%   the epochs of its ref, window and selection, with no baseline or
%   column.
%
%   Errors: EphysAnalysisRunner:FigureSkipped (figureSkipReason: what the
%   dataset lacks for the figure), and epochTable's.
%
%   See also figureCompute, epochTable, epochSpikes, epochEvents,
%   EphysAnalysisScript.preview.

arguments
    src (1,1) struct
    spec (1,1) struct
end

spec.enabled = true;   % a figure that is off is still aligned, as the preview computes it
[reason, LR] = figureSkipReason(src, spec);
if reason ~= ""
    error('EphysAnalysisRunner:FigureSkipped', 'Figure "%s" cannot be computed for %s: %s.', spec.id, src.name, reason);
end
plan = figureEpochPlan(src, spec, LR);
[E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, ...
    Baseline=plan.figureBase, Columns=plan.figureCols);
end
