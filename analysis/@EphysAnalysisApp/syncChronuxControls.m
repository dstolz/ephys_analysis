function syncChronuxControls(obj)
%syncChronuxControls  Show the Chronux tab's rows and sections the analysis uses; say what the tapers come to.
%   The signal and its channels for the continuous analyses, the spike
%   trains for the spike ones (the signal's field channel for the
%   spike-field coherence); the pair rows of a coherence; the window,
%   groups and event rows for epochs, the stretch and segments for a
%   stretch (a spectrogram's segments are its moving window); TW and K or
%   W and p; the moving window for a spectrogram or a coherence over time,
%   and (epochs) the baseline for a spectrogram; error bars, layout and y
%   limits for a spectrum or a coherence, color limits for a spectrogram,
%   the phase for a coherence. Then the sections are packed (formStack),
%   and Compute follows what the file holds for the analysis.
C = obj.ChronuxControls;
if isempty(fieldnames(C)); return; end
sec = obj.ChronuxSections;
a = string(C.analysis.Value);
aligned = string(C.timeBase.Value) == "aligned";
spectrum = a == "spectrum";
specgram = a == "specgram";
coh = a == "coherence";
spikeSpectrum = a == "spikeSpectrum";
spikeField = a == "spikeField";
unitCoh = a == "unitCoherence";
overTime = coh && C.overTime.Value;   % a coherogram: the moving window, as a spectrogram
moving = specgram || overTime;
spike = spikeSpectrum || spikeField || unitCoh;
needSignal = spectrum || specgram || coh || spikeField;   % reads a continuous signal
bars = spectrum || spikeSpectrum || spikeField || unitCoh || (coh && ~overTime);   % one spectrum per tile
pair = string(C.pairMode.Value) == "pair";
wp = string(C.taperMode.Value) == "Wp";
for key = ["eventText" "pre" "useGroups"]; sec = formShow(sec, key, aligned); end
sec = formShow(sec, "from", ~aligned);
sec = formShow(sec, "segment", ~aligned && ~moving);
sec = formShow(sec, "TW", ~wp);
sec = formShow(sec, "W", wp);
sec = formShow(sec, "overTime", coh);
sec = formShow(sec, "pairMode", coh || unitCoh);
sec = formShow(sec, "seed", coh);
sec = formShow(sec, "partner", coh && pair);
sec = formShow(sec, "unitSeed", unitCoh);
sec = formShow(sec, "unitPartner", unitCoh && pair);
sec = formShow(sec, "fieldChannel", spikeField);
sec = formShow(sec, "err", bars);
for key = ["layout" "showErr" "ylim"]; sec = formShow(sec, key, bars); end
sec = formShow(sec, "detrend", needSignal);
sec = formShow(sec, "spikeFs", spikeSpectrum || unitCoh);
sec = formShow(sec, "fscorr", spike);
sec = formShow(sec, "scale", spectrum || specgram || spikeSpectrum);
sec = formShow(sec, "showPhase", (coh && ~overTime) || spikeField || unitCoh);
sec = formShow(sec, "clim", moving);
for i = 1:numel(sec)
    switch sec(i).Name
        case "moving",   sec(i).Visible = moving;
        case "baseline", sec(i).Visible = specgram && aligned;
    end
end
switch a
    case "spectrum"
        C.about.Text = "The power at each frequency, averaged over the trials and tapers (mtspectrumc, trialave 1), " + ...
            "each channel and trial group its own, with error bars.";
    case "specgram"
        C.about.Text = "The power over time and frequency (mtspecgramc): a spectrum over each moving window, " + ...
            "averaged over the epochs; over a stretch, one per clear stretch.";
    case "coherence"
        C.about.Text = "How consistently two channels keep their phase at each frequency (coherencyc, trialave 1): " + ...
            "the coherence, 0 to 1, over the trials, with its phase where it is over the level independent signals stay under.";
    case "spikeSpectrum"
        C.about.Text = "The spectrum of each spike train (mtspectrumpt), averaged over the trials: a rhythm is a peak, " + ...
            "a refractory period a dip below the mean rate (dotted line) it tends to at high frequencies.";
    case "spikeField"
        C.about.Text = "How locked each spike train is to the field channel (coherencycpt): the coherence at each " + ...
            "frequency over the trials, with its phase where it is over the level independent signals stay under.";
    case "unitCoherence"
        C.about.Text = "How locked two spike trains are to each other (coherencypt): the coherence at each " + ...
            "frequency over the trials, with its phase where it is over the level independent signals stay under.";
end
[ok, why] = chronuxCanCompute(obj.ChronuxIndex, a, string(C.spikeSource.Value));
if ~ok && why ~= ""
    C.about.Text = why + " " + C.about.Text;
end
% what the tapers come to over the length T each spectrum is computed over
if moving
    T = C.mwWin.Value; over = "the moving window";
elseif aligned
    T = C.post.Value - C.pre.Value; over = "the epoch";
else
    T = C.segment.Value; over = "a segment";
end
if ~(T > 0)
    C.taperText.Text = "The window is empty.";
elseif wp
    try
        tap = ChronuxDataset.tapersFor(C.W.Value, T, P=C.p.Value);
        C.taperText.Text = sprintf("Tapers [%.3g %d] over %s (%.3g s).", tap(1), tap(2), over, T);
    catch ME
        C.taperText.Text = string(ME.message);
    end
else
    C.taperText.Text = sprintf("Smoothed over ±%.3g Hz over %s (%.3g s).", C.TW.Value / T, over, T);
    if C.K.Value > 2 * C.TW.Value - 1
        C.taperText.Text = C.taperText.Text + sprintf(" K above 2TW-1 = %g.", 2 * C.TW.Value - 1);
    end
end
obj.ChronuxSections = formStack(sec, obj.ChronuxEditorGrid);
% the left column: the signal and channels, the spike trains
rows = {22, 26, 22, 64, 30, 22, 36, 30, 26, 22, '1x', 30, 26, 22, '1x', 30};
chans = spectrum || specgram || coh;
if ~needSignal; rows(9) = {0}; end
if ~chans; rows(10:12) = {0}; end
if ~spike; rows(13:16) = {0}; end
C.left.RowHeight = rows;
set([C.signalLabel C.signal], 'Visible', matlab.lang.OnOffSwitchState(needSignal));
set([C.channelsLabel C.channels C.allChannels], 'Visible', matlab.lang.OnOffSwitchState(chans));
set([C.spikeLabel C.spikeSource C.unitsLabel C.units C.allUnits], 'Visible', matlab.lang.OnOffSwitchState(spike));
if ~ismember(obj.ChronuxState, ["computing" "creating"])
    obj.ChronuxComputeButton.Enable = matlab.lang.OnOffSwitchState(ok && ChronuxDataset.hasChronux());
end
end
