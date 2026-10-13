function syncChronuxControls(obj)
%syncChronuxControls  Show the Chronux tab's rows and sections the analysis uses; say what the tapers come to.
%   The window, groups and event rows for epochs, the stretch and
%   segments for a stretch (a spectrogram's segments are its moving
%   window); TW and K or W and p; the moving window and (epochs) the
%   baseline for a spectrogram; error bars, layout and y limits for a
%   spectrum, color limits for a spectrogram. Then the sections are packed
%   (formStack).
C = obj.ChronuxControls;
if isempty(fieldnames(C)); return; end
sec = obj.ChronuxSections;
a = string(C.analysis.Value);
aligned = string(C.timeBase.Value) == "aligned";
spectrum = a == "spectrum";
specgram = a == "specgram";
wp = string(C.taperMode.Value) == "Wp";
for key = ["eventText" "pre" "useGroups"]; sec = formShow(sec, key, aligned); end
sec = formShow(sec, "from", ~aligned);
sec = formShow(sec, "segment", ~aligned && ~specgram);
sec = formShow(sec, "TW", ~wp);
sec = formShow(sec, "W", wp);
sec = formShow(sec, "err", spectrum);
for key = ["layout" "showErr" "ylim"]; sec = formShow(sec, key, spectrum); end
sec = formShow(sec, "clim", specgram);
for i = 1:numel(sec)
    switch sec(i).Name
        case "moving",   sec(i).Visible = specgram;
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
end
% what the tapers come to over the length T each spectrum is computed over
if specgram
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
end
