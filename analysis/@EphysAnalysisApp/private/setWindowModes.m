function setWindowModes(dd, modes, v)
%setWindowModes  Offer the epoch-window MODES in DD and show V (kept when not among them).
%   The items spell out each mode's window: fixed [t0+pre, t0+post],
%   between [t0+pre, stop+post]. V defaults to DD's value.
if nargin < 3; v = string(dd.Value); end
labels = dictionary(["fixed" "between"], ["fixed: [t0+pre, t0+post]" "between: [t0+pre, stop+post]"]);
modes = unique([reshape(string(modes), 1, []) string(v)], 'stable');
items = modes;
known = isKey(labels, modes);
items(known) = labels(modes(known));
dd.Items = items;
dd.ItemsData = modes;
dd.Value = string(v);
end
