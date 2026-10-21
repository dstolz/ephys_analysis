function S = figureChronuxSettings(type, op, W, analysis)
%figureChronuxSettings  The Chronux settings of a spectral figure panel, from its options, checked.
%   S = figureChronuxSettings(TYPE, OP, W, ANALYSIS) overlays the options OP
%   of a panel of TYPE ("spectrum", "spectrogram" or "coherence";
%   panelTypes().DefaultOptions) on chronuxSettings() and checks them
%   there: S.analysis = ANALYSIS (default: "spectrum", "specgram" or
%   "coherence" by TYPE; the compute passes "spikeSpectrum",
%   "spikeSpecgram", "spikeField" or "unitCoherence" for spike layers),
%   S.window = W ([pre post] s, the
%   panel's window; [] keeps the default), and from OP: timeBase, range,
%   segmentSec, taperMode, TW, K, W, p, pad, fpass, err, errP, detrend,
%   spikeFs, movingwin, overTime, the baseline (OP.baseline.Mode and
%   .Window as baseline / baselineWindow) and display.scale / showPhase.
%   A spectrogram is always on the aligned time base. Errors are
%   chronuxSettings' (chronuxSettings:BadValue, chronuxSettings:Baseline):
%   validate reports their message as the panel's options error.
%
%   See also chronuxSettings, EphysAnalysisConfig.panelTypes, computeSpectrumPanel.
arguments
    type (1,1) string
    op (1,1) struct
    W double = []
    analysis (1,1) string = ""
end
if analysis == ""
    switch type
        case "spectrogram", analysis = "specgram";
        case "coherence",   analysis = "coherence";
        otherwise,          analysis = "spectrum";
    end
end
s = struct('analysis', analysis);
if numel(W) == 2; s.window = reshape(double(W), 1, 2); end
for f = ["timeBase" "range" "segmentSec" "taperMode" "TW" "K" "W" "p" "pad" "fpass" "err" "errP" "detrend" ...
        "spikeFs" "movingwin" "overTime"]
    if isfield(op, f); s.(f) = op.(f); end
end
if isfield(op, 'baseline') && isstruct(op.baseline)
    s.baseline = op.baseline.Mode;
    s.baselineWindow = op.baseline.Window;
end
d = struct();
if isfield(op, 'scale'); d.scale = op.scale; end
if isfield(op, 'showPhase'); d.showPhase = op.showPhase; end
if ~isempty(fieldnames(d)); s.display = d; end
S = chronuxSettings(s);
end
