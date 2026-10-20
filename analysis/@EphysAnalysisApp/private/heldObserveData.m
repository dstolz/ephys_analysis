function d = heldObserveData(obj, d)
%heldObserveData  The data a figure observes on the active dataset: D when the dataset holds it, else the first type it holds.
%   D = heldObserveData(OBJ, D) keeps D (an ObserveData value) when there
%   is no active dataset, when D is "dataset", or when the active dataset
%   holds it (observeHeld); else it is the first data type the dataset
%   holds, in ObserveData's order (sorted units, detected spikes, LFP,
%   MUA, SPIKE, AUX), else "dataset". onAddFigure and commitFigureEdit
%   use it for a figure's observe.data.
%
%   See also observeHeld, EphysAnalysisConfig.followedData.
if d == "dataset" || isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch
    return
end
types = EphysAnalysisConfig.ObserveData;
has = observeHeld(src);
if ~has(types == d); d = types(find(has, 1)); end
end
