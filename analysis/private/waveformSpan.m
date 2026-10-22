function [t, m, S] = waveformSpan(t, m, S, timeMs)
%waveformSpan  A waveform's samples inside a time span: the x scale of a panel's waveform (options.waveform.timeMs).
%   [T, M, S] = waveformSpan(T, M, S, TIMEMS) keeps the samples of the
%   times T (ms from the spike, a column), the mean M (a column) and the
%   spikes S ([nt x k], or []) whose time is in TIMEMS, [from to] ms
%   (-Inf / Inf: the cut's edge). TIMEMS [] keeps them all, and so does a
%   span holding fewer than two of them (it misses the waveform): the
%   whole cut is drawn rather than nothing. Used by waveformInset,
%   renderWaveforms and drawWaveformsPanel.
%
%   See also waveformInset, renderWaveforms, unitWaveforms.
if numel(timeMs) ~= 2 || isempty(t)
    return
end
k = t(:) >= timeMs(1) & t(:) <= timeMs(2);
if nnz(k) < 2
    return
end
t = t(k);
if ~isempty(m); m = m(k); end
if ~isempty(S); S = S(k, :); end
end
