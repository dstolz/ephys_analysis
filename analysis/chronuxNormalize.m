function [S, units] = chronuxNormalize(S, t, mode, window, winSec, fs)
%chronuxNormalize  A spectrogram against its baseline, frequency by frequency.
%   [S, UNITS] = chronuxNormalize(S, T, MODE, WINDOW, WINSEC, FS): S is
%   [nT x nF x ...] power on the times T (s from the event, the centers of
%   moving windows WINSEC long; 0 when left out); each frequency (and
%   channel, group) is compared with its mean power B over the moving
%   windows that lie wholly inside WINDOW [b0 b1] s (a window reaching past
%   the baseline's end holds post-event power, which would dilute the
%   change it is compared with). With FS, a window is round(WINSEC*FS)
%   samples at FS Hz, and it lies inside when its first and last samples
%   do (they are (n-1)/FS s apart, so a window starting on b0 and as long
%   as the baseline counts); without it, a window spans WINSEC.
%     "db"       10*log10(S ./ B)   (dB change)
%     "percent"  100 * (S - B) ./ B (% change)
%     "zscore"   (S - B) ./ SD      (z; SD over the baseline's times)
%     "ratio"    S ./ B
%     "none"     S as it is
%   UNITS names what S then holds. Errors chronuxNormalize:NoBaseline when
%   no moving window lies inside WINDOW (a "zscore": fewer than two),
%   chronuxNormalize:BadMode for a
%   MODE not listed. NaN windows are left out of B (and SD).
%
%   chronuxSpecgram and chronuxSpikeSpecgram normalize with it (their
%   windows are samples: FS given); so does a script of its own Chronux
%   spectrograms, for the analysis app's rule (S_ExampleChronuxSpikes:
%   mtspecgrampt's windows span WINSEC around each time, no FS).
%
%   See also chronuxSpecgram, chronuxSpikeSpecgram, chronuxSettings.
mode = string(mode);
if ~isscalar(mode) || ~ismember(mode, ["none" "db" "percent" "zscore" "ratio"])
    error('chronuxNormalize:BadMode', 'The baseline mode must be "none", "db", "percent", "zscore" or "ratio".');
end
if mode == "none"; units = ""; return; end
if nargin < 5 || isempty(winSec); winSec = 0; end
span = winSec;   % from a window's first sample to its last
if nargin >= 6 && ~isempty(fs) && winSec > 0
    span = (round(winSec * fs) - 1) / fs;
end
half = span / 2;
in = t(:) - half >= window(1) - 1e-9 & t(:) + half <= window(2) + 1e-9;
if ~any(in)
    error('chronuxNormalize:NoBaseline', ['No %g s spectrogram window lies inside the baseline [%g %g] s: ' ...
        'lengthen the baseline (it needs at least one whole moving window) or shorten the moving window.'], ...
        winSec, window(1), window(2));
end
B = mean(S(in, :, :, :), 1, 'omitnan');
switch mode
    case "db"
        S = 10 * log10(S ./ B);
        units = "dB change";
    case "percent"
        S = 100 * (S - B) ./ B;
        units = "% change";
    case "zscore"
        if nnz(in) < 2   % the SD of one window is 0: every z would be Inf
            error('chronuxNormalize:NoBaseline', ['A z-score needs at least two moving windows inside the baseline [%g %g] s ' ...
                '(the SD is over them), and one lies there: lengthen the baseline by a step or more, or pick another baseline mode.'], ...
                window(1), window(2));
        end
        sd = std(S(in, :, :, :), 0, 1, 'omitnan');
        S = (S - B) ./ sd;
        units = "z";
    case "ratio"
        S = S ./ B;
        units = "ratio";
end
end
