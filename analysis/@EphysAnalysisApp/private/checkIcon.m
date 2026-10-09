function img = checkIcon(state)
%checkIcon  A 16 x 16 check box for a plot tree node: STATE "on" (ticked), "off" or "mixed" (some plots of a group).
%   A truecolor array for a tree node's Icon. The tree is a multi-select
%   tree, which MATLAB draws without check boxes (only the check-box tree has
%   them, and it picks one node at a time), so the boxes are icons.
persistent cache
if isempty(cache)
    cache = struct();
end
state = char(state);
if isfield(cache, state)
    img = cache.(state);
    return
end
img = uint8(255 * ones(16, 16, 3));
edge = [70 70 70];
box = false(16, 16);
box([2 15], 2:15) = true;
box(2:15, [2 15]) = true;
paint(box, edge);
switch state
    case "on"
        tick = false(16, 16);
        for rc = [8 4; 9 5; 10 6; 11 7; 10 8; 9 9; 8 10; 7 11; 6 12; 5 13].'
            tick(rc(1), rc(2):rc(2)+1) = true;
        end
        paint(tick, [0 120 60]);
    case "mixed"
        part = false(16, 16);
        part(5:12, 5:12) = true;
        paint(part, [0 120 60]);
    case "off"
    otherwise
        error('EphysAnalysisApp:BadCheckState', 'Unknown check state "%s".', state);
end
cache.(state) = img;

    function paint(mask, rgb)
        for c = 1:3
            plane = img(:, :, c);
            plane(mask) = rgb(c);
            img(:, :, c) = plane;
        end
    end
end
