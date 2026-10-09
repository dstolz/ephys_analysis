function c = rasterMarkColor(color, m)
%rasterMarkColor  The color of a raster's M-th event mark (rasterEvents.color).
%   COLOR "" gives each mark its own from a fixed list (none black, the
%   ticks' color, nor the stop dots' red); a color name or hex code
%   (validatecolor) gives every mark that color.
color = string(color);
if color ~= ""
    try
        c = validatecolor(color);
        return
    catch
        % not a color (validate warns): the automatic colors
    end
end
list = [0 0.447 0.741; 0.466 0.674 0.188; 0.494 0.184 0.556; 0.929 0.694 0.125; 0.301 0.745 0.933; 0 0.6 0.5];
c = list(mod(m - 1, size(list, 1)) + 1, :);
end
