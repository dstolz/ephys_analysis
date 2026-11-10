function [S, units] = chronuxNormalize(S, t, mode, window, winSec)
%chronuxNormalize  A spectrogram against its baseline, frequency by frequency.
%   [S, UNITS] = chronuxNormalize(S, T, MODE, WINDOW, WINSEC): S is
%   [nT x nF x ...] power on the times T (s from the event, the centers of
%   moving windows WINSEC long; 0 when left out); each frequency (and
%   channel, group) is compared with its mean power B over the moving
%   windows that lie wholly inside WINDOW [b0 b1] s (a window reaching past
%   the baseline's end holds post-event power, which would dilute the
%   change it is compared with):
%     "db"       10*log10(S ./ B)   (dB change)
%     "percent"  100 * (S - B) ./ B (% change)
%     "zscore"   (S - B) ./ SD      (z; SD over the baseline's times)
%     "ratio"    S ./ B
%     "none"     S as it is
%   UNITS names what S then holds. Errors chronuxNormalize:NoBaseline when
%   no moving window lies inside WINDOW.
if mode == "none"; units = ""; return; end
if nargin < 5 || isempty(winSec); winSec = 0; end
half = winSec / 2;
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
        sd = std(S(in, :, :, :), 0, 1, 'omitnan');
        S = (S - B) ./ sd;
        units = "z";
    case "ratio"
        S = S ./ B;
        units = "ratio";
end
end
