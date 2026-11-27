function key = previewDataKey(obj, k)
%previewDataKey  What figure K's computed data depend on now: a preview computed with another key computes again.
%   KEY = previewDataKey(OBJ, K) is figureViewKey(OBJ, K) with its figure
%   replaced by the figure's data spec (figureDataSpec of
%   Config.figureFor(K)) and without its page: the dataset, the
%   observation picked, the scan and what the compute reads, not the
%   titles, labels, places, colors, the page and other looks only the
%   drawing reads. Two previews with the same key
%   compute nothing the second time (the runner keeps what the first one
%   computed: EphysAnalysisRunner.computeFigure, Reuse), so an edit that
%   leaves the key as it was costs only the drawing (previewCost). [] when
%   K is no figure.
%
%   See also previewCost, figureViewKey, figureDataSpec.
key = figureViewKey(obj, k);
if isempty(key); return; end
spec = obj.Config.figureFor(k);
spec.enabled = true;   % (as refreshFigurePreview computes it)
key.figure = figureDataSpec(spec);
key = rmfield(key, 'page');   % (the page is how it is drawn, not what is computed)
end
