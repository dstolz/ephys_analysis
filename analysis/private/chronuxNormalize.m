function [S, units] = chronuxNormalize(S, t, mode, window)
%chronuxNormalize  A spectrogram against its baseline, frequency by frequency.
%   [S, UNITS] = chronuxNormalize(S, T, MODE, WINDOW): S is [nT x nF x ...]
%   power on the times T (s from the event); each frequency (and channel,
%   group) is compared with its mean power B over the times in WINDOW
%   [b0 b1] s:
%     "db"       10*log10(S ./ B)   (dB change)
%     "percent"  100 * (S - B) ./ B (% change)
%     "zscore"   (S - B) ./ SD      (z; SD over the baseline's times)
%     "ratio"    S ./ B
%     "none"     S as it is
%   UNITS names what S then holds. Errors chronuxNormalize:NoBaseline when
%   no time lies in WINDOW.
if mode == "none"; units = ""; return; end
in = t(:) >= window(1) - 1e-9 & t(:) <= window(2) + 1e-9;
if ~any(in)
    error('chronuxNormalize:NoBaseline', ['No spectrogram window is centered in the baseline [%g %g] s: ' ...
        'widen it or shorten the moving window.'], window(1), window(2));
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
