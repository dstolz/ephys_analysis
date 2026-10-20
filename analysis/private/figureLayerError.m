function reason = figureLayerError(ME)
%figureLayerError  A figure layer's skip reason from an error its data raised, or the error again.
%   REASON = figureLayerError(ME) is the message of ME when it says the
%   dataset lacks what a layer or a panel's own epochs need (no unit left
%   after the selection, no event of a line, no column, no value, no
%   probe map, a signal's baseline with no sample in the window; for the
%   Chronux panels no trial or segment left, a pair or field channel not
%   at hand, a moving window longer than the epoch, a result over its
%   limit, settings chronuxSettings refuses, ...): the
%   layer (or the panel) is skipped with it and the
%   rest of the figure is still computed. ChronuxDataset:NoChronux (the
%   toolbox is not on the MATLAB path) gives "Chronux is not on the path".
%   Any other error, and above all
%   EphysAnalysisRunner:Canceled, is rethrown.
%
%   See also EphysAnalysisRunner.computeFigure, figureSkipReason.

skippable = ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft" ...
    "selectChannels:NoSignal" "selectChannels:BadChannels" ...
    "resolveEvents:NoEvents" "resolveEvents:NoLine" "resolveEvents:NoTrials" "resolveEvents:NoParam" "resolveEvents:BadParam" ...
    "epochEvents:NoLine" "epochEvents:NoTrials" "epochIntervals:NoOffsets" "epochTable:NoEpochs" "epochTable:NoColumn" ...
    "probeMapValues:NoProbe" "spikePSTH:BadWindow" "spikePSTH:NoneModulated" "tuningCurve:NoValues" ...
    "evokedPotential:BadBaseline" ...
    "chronuxCoherence:BadPair" "chronuxSpikeField:NoField" "chronuxUnitCoherence:BadPair" "chronuxSpecgram:Short" ...
    "chronuxSpecgram:TooLarge" "chronuxCoherence:Short" "chronuxCoherence:TooLarge" "chronuxTimeBase:NoTrials" ...
    "chronuxTimeBase:BadValue" "chronuxSettings:BadValue" "chronuxSettings:Baseline" ...
    "chronuxNormalize:NoBaseline" "chronuxParams:Fpass"];   % no window centered in the baseline; fpass above the layer's Nyquist
if string(ME.identifier) == "ChronuxDataset:NoChronux"   % the spectral panels: the toolbox, not the data
    reason = "Chronux is not on the path";
    return
end
if ~ismember(string(ME.identifier), skippable)
    rethrow(ME);
end
reason = string(ME.message);
end
