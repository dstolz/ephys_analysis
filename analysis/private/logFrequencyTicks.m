function logFrequencyTicks(ax)
%logFrequencyTicks  Label a y axis of log10 frequency (logFrequencyRows' rows) in Hz, as a log axis is labeled.
%   logFrequencyTicks(AX) puts AX's y ticks at the round frequencies its y
%   limits (log10 Hz: set them first) span: 1, 2 and 5 times a power of 10
%   (labeled "2", "5", "10", "20", "50", "100" Hz), only the powers of 10
%   over more than three decades, every whole multiple of a power of 10
%   when fewer than two of those fit, else three rounded frequencies. The
%   other whole multiples (3, 4, 6, ... x 10^k) get minor ticks.
%
%   See also logFrequencyRows, drawSpectrogramPanel, renderChronux.
yl = ylim(ax);
tol = 1e-9;
k = (floor(yl(1)):ceil(yl(2))).';
v = sort(reshape((1:9) .* 10 .^ k, 1, []));
v = v(v >= 10 ^ yl(1) * (1 - tol) & v <= 10 ^ yl(2) * (1 + tol));
lead = round(v ./ 10 .^ floor(log10(v) + tol));   % each one's leading digit
if diff(yl) > 3
    major = v(lead == 1);
else
    major = v(ismember(lead, [1 2 5]));
end
if numel(major) < 2; major = v; end
if numel(major) < 2; major = unique(round(10 .^ linspace(yl(1), yl(2), 3), 2, 'significant')); end
set(ax, 'YTick', log10(major), 'YTickLabel', cellstr(compose("%g", major)));
minor = setdiff(v, major);
if ~isempty(minor)
    ax.YAxis.MinorTickValues = log10(minor);
    ax.YMinorTick = 'on';
end
end
