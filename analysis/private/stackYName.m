function s = stackYName(what, L, units)
%stackYName  A line stack's y label: what its rows are, and their scale.
%   S = stackYName(WHAT, L, UNITS) for a stackLayout L: "<WHAT> (<height>
%   <UNITS> per row)" when its rows share one scale (L.shared: yLimMode
%   "rows", "batch" or "fixed"), "<WHAT> (each row on its own scale)" when
%   each row fits itself (yLimMode "auto": each row's top is on the right
%   axis). WHAT names the rows (the groups' parameters, "Channel", a
%   tuning curve's series parameter); UNITS ("" = none) the values'.
%
%   See also stackLayout, stackAxes.
if L.shared
    s = strip(sprintf("%s (%s %s", what, sprintf('%.3g', L.height), units)) + " per row)";
else
    s = what + " (each row on its own scale)";
end
end
