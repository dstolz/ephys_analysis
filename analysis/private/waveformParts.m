function p = waveformParts(W, u, wave)
%waveformParts  What a waveform drawing shows of one unit: its mean, spikes and error band, in the time span drawn.
%   P = waveformParts(W, U, WAVE) takes unit U of W (unitWaveforms) and the
%   waveform settings WAVE (defaults("Waveform"): mode, timeMs, band) and
%   gives
%     has       the unit has a waveform (else nothing below is set)
%     t, m, S   its times (ms from the spike), mean and spikes ([nt x k])
%               inside WAVE.timeMs (waveformSpan); S is [] when not drawn
%     spikes, mean   what the mode draws: "subsample" / "both" the spikes,
%               "mean" / "both" the mean. A template (W.from "template":
%               mode "template", or spikes that cannot be read) is drawn
%               as the mean whatever the mode, and so is a unit without
%               spikes; mode "off" is read as "both"
%     band, bandLo, bandHi   the mean -/+ WAVE.band ("std": the SD of the
%               spikes the mean is over, W.sd; "sem": that SD over the
%               square root of their number, W.nMean) when the mean is
%               drawn and is over spikes; band false and [] otherwise
%     lo, hi    the lowest and highest value drawn, band included (hi > lo)
%     template  the mean is the unit's template
%     pp        the mean's peak-to-peak amplitude over the whole cut
%   W without sd / nMean (a hand-made one) takes the SD of its spikes.
%   Used by renderWaveforms, waveformInset, drawWaveformsPanel and
%   renderProbeMap.
%
%   See also unitWaveforms, waveformSpan, waveformGlyphs, errorPatch.

p = struct('has', false, 't', [], 'm', [], 'S', [], 'spikes', false, 'mean', false, 'band', false, ...
    'bandLo', [], 'bandHi', [], 'lo', NaN, 'hi', NaN, 'template', false, 'pp', NaN);
if isempty(W) || ~isfield(W, 'mean') || u > numel(W.mean) || isempty(W.mean{u}); return; end
mode = string(wave.mode);
if mode == "off"; mode = "both"; end
p.has = true;
p.pp = max(W.mean{u}) - min(W.mean{u});   % the unit's, whatever span is drawn
S0 = W.spikes{u};
sd = [];
n = 0;
if isfield(W, 'sd') && u <= numel(W.sd) && ~isempty(W.sd{u})
    sd = W.sd{u};
    n = size(S0, 2);
    if isfield(W, 'nMean') && u <= numel(W.nMean); n = W.nMean(u); end
elseif size(S0, 2) > 1
    sd = std(S0, 0, 2);
    n = size(S0, 2);
end
t = W.timeMs{u}(:);
[p.t, p.m, p.S] = waveformSpan(t, W.mean{u}(:), S0, wave.timeMs);
if ~isempty(sd); [~, sd] = waveformSpan(t, sd(:), [], wave.timeMs); end
p.template = W.from(u) == "template";
p.spikes = ismember(mode, ["subsample" "both"]) && ~isempty(p.S) && ~p.template;
p.mean = ismember(mode, ["mean" "both"]) || ~p.spikes;
if ~p.spikes; p.S = []; end
band = "off";
if isfield(wave, 'band'); band = string(wave.band); end
if p.mean && ~p.template && mode ~= "template" && band ~= "off" && numel(sd) == numel(p.m) && n > 1
    e = sd;
    if band == "sem"; e = sd / sqrt(n); end
    p.band = true;
    p.bandLo = p.m - e;
    p.bandHi = p.m + e;
end
V = p.m;
if p.spikes; V = [V p.S]; end
if p.band; V = [V p.bandLo p.bandHi]; end
p.lo = min(V(:));
p.hi = max(V(:));
if ~(p.hi > p.lo); p.lo = p.lo - 1; p.hi = p.hi + 1; end
end
