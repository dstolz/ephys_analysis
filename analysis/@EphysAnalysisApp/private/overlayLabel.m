function t = overlayLabel(ov, k)
%overlayLabel  An overlay's line in the plot editor's list: its place, name and what it draws.
%   t = overlayLabel(OV, K) for the K-th overlay OV of a plot, e.g.
%   "2. Stim onset  (x = 0)", "3. Patch 1  (y 5 to 10)"; "[off]" at the end
%   when it is disabled. A name left blank shows as "Overlay K", as it is
%   drawn (drawOverlays).
name = strtrim(string(ov.name));
if name == ""; name = "Overlay " + k; end
if ov.shape == "region"
    what = ov.axis + " " + num(ov.from) + " to " + num(ov.to);
else
    what = ov.axis + " = " + num(ov.value);
end
t = k + ". " + name + "  (" + what + ")";
if ~ov.enabled; t = t + "  [off]"; end
end


function s = num(x)
s = string(sprintf('%.6g', x));
end
