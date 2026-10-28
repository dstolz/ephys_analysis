function G = waveformGlyphs(W, P, X, Y, gw, gh, wave)
%waveformGlyphs  Units' waveforms as glyphs centered on points: the coordinates of their lines, for a drawing on the probe.
%   G = waveformGlyphs(W, P, X, Y, GW, GH, WAVE) lays out the units of W
%   (unitWaveforms) whose parts P ({nU x 1}, waveformParts) have a
%   waveform and whose centers X, Y ([nU x 1], data units) are finite:
%   each a glyph GW wide and GH tall, its time across the width and its
%   amplitude up the height as WAVE.ampScale says ("unit": each fills its
%   height; "common": the largest peak-to-peak range of the units with
%   values of the same kind (W.units) does; "fixed": WAVE.ampLim does,
%   what lies beyond it drawn at its edge). G fields, one per unit:
%     placed   [nU x 1] the unit is drawn
%     spikes   {nU x 1} [n x 2] its spikes, one NaN-joined line ([] none)
%     mean     {nU x 1} [n x 2] its mean, then a NaN row ([] none)
%     band     {nU x 1} [n x 3] its error band: x, low and high edge, for
%              errorPatch ([] none)
%     span     [nU x 1] the amplitude a glyph's height is in the common
%              or fixed scale (0: each unit's own), for a scale bar
%   Used by renderWaveforms (the probe layout) and renderProbeMap.
%
%   See also waveformParts, renderWaveforms, renderProbeMap.

nU = numel(P);
G = struct('placed', false(nU, 1), 'spikes', {cell(nU, 1)}, 'mean', {cell(nU, 1)}, 'band', {cell(nU, 1)}, ...
    'span', zeros(nU, 1));
fixed = wave.ampScale == "fixed" && numel(wave.ampLim) == 2 && wave.ampLim(2) > wave.ampLim(1);
for u = 1:nU
    p = P{u};
    if ~p.has || ~isfinite(X(u)) || ~isfinite(Y(u)); continue; end
    G.placed(u) = true;
    lo = p.lo; hi = p.hi;
    span1 = hi - lo;
    if wave.ampScale == "common"
        G.span(u) = commonSpan(W, P, W.units(u));
        span1 = G.span(u);
    elseif fixed
        lo = wave.ampLim(1);
        hi = wave.ampLim(2);
        G.span(u) = hi - lo;
        span1 = G.span(u);
    end
    if ~(span1 > 0); span1 = 1; end
    tspan = max(p.t) - min(p.t);
    if ~(tspan > 0); tspan = 1; end
    gx = X(u) + gw * ((p.t - min(p.t)) / tspan - 0.5);
    at = @(v) Y(u) + gh * (v - (lo + hi) / 2) / span1;
    if fixed; at = @(v) Y(u) + gh * (min(max(v, lo), hi) - (lo + hi) / 2) / span1; end   % clipped at the fixed range
    if p.spikes
        k = size(p.S, 2);
        G.spikes{u} = [repmat([gx; NaN], k, 1), reshape([at(p.S); NaN(1, k)], [], 1)];
    end
    if p.mean
        G.mean{u} = [gx, at(p.m); NaN NaN];
    end
    if p.band
        G.band{u} = [gx, at(p.bandLo), at(p.bandHi)];
    end
end
end


function span = commonSpan(W, P, units)
%commonSpan  The largest peak-to-peak range of the drawn units whose values are of the kind UNITS.
span = 0;
for u = 1:numel(P)
    if ~P{u}.has || W.units(u) ~= units; continue; end
    span = max(span, P{u}.hi - P{u}.lo);
end
end
