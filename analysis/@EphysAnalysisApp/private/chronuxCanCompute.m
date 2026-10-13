function [ok, why] = chronuxCanCompute(I, analysis, source)
%chronuxCanCompute  Whether a Chronux file has what an analysis reads, and what is missing.
%   [OK, WHY] = chronuxCanCompute(I, ANALYSIS, SOURCE): I the file's index
%   (loadChronuxExport; [] when there is no file), ANALYSIS a
%   chronuxSettings analysis, SOURCE the spike trains asked for ("units" or
%   "detected"). A spectrum, spectrogram or coherence needs a continuous
%   signal; the spike spectrum and unit-unit coherence the spike trains;
%   spike-field coherence both. WHY says what is missing ("" when OK).
ok = false;
why = "";
if isempty(I); return; end
sig = ~isempty(fieldnames(I.signals));
if string(source) == "units"
    n = numel(I.sp);
    what = "sorted units";
else
    n = numel(I.spDetected);
    what = "threshold detections";
end
needSignal = ismember(analysis, ["spectrum" "specgram" "coherence" "spikeField"]);
needSpikes = ismember(analysis, ["spikeSpectrum" "spikeField" "unitCoherence"]);
if needSignal && ~sig
    why = "The Chronux file holds no continuous signal.";
elseif needSpikes && n == 0
    why = "The Chronux file holds no " + what + ".";
else
    ok = true;
end
end
