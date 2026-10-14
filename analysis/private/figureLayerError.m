function reason = figureLayerError(ME)
%figureLayerError  A figure layer's skip reason from an error its data raised, or the error again.
%   REASON = figureLayerError(ME) is the message of ME when it says the
%   dataset lacks what a layer or a panel's own epochs need (no unit left
%   after the selection, no event of a line, no column, no value, no
%   probe map, a signal's baseline with no sample in the window, ...): the
%   layer (or the panel) is skipped with it and the
%   rest of the figure is still computed. Any other error, and above all
%   EphysAnalysisRunner:Canceled, is rethrown.
%
%   See also EphysAnalysisRunner.computeFigure, figureSkipReason.

skippable = ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft" ...
    "selectChannels:NoSignal" "selectChannels:BadChannels" ...
    "resolveEvents:NoEvents" "resolveEvents:NoLine" "resolveEvents:NoTrials" "resolveEvents:NoParam" "resolveEvents:BadParam" ...
    "epochEvents:NoLine" "epochEvents:NoTrials" "epochTable:NoEpochs" "epochTable:NoColumn" ...
    "probeMapValues:NoProbe" "spikePSTH:BadWindow" ...
    "evokedPotential:BadBaseline"];
if ~ismember(string(ME.identifier), skippable)
    rethrow(ME);
end
reason = string(ME.message);
end
