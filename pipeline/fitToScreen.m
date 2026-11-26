function pos = fitToScreen(pos, opts)
%fitToScreen  A figure position that fits the screen it is on.
%   POS = fitToScreen(POS) shrinks POS ([x y width height], pixels, as a
%   figure's Position) to its screen less room for the title bar, menus and
%   the taskbar, then moves it so the whole window is on that screen. The
%   screen is the monitor the window overlaps most (groot's
%   MonitorPositions), so a window kept on a second monitor stays there;
%   one that overlaps none, as after that monitor was unplugged, goes to the
%   primary screen (groot's ScreenSize). A position that already fits is
%   returned unchanged. Used for a window's saved or default position, which
%   may come from a larger display or another layout.
%   Monitors=ROWS ([x y w h] each) and Primary=[x y w h] name the screens
%   instead of asking groot (the tests do).
arguments
    pos (1,4) double
    opts.Monitors (:,4) double = reshape(groot().MonitorPositions, [], 4)
    opts.Primary (1,4) double = groot().ScreenSize
end
r = opts.Primary;   % [x y w h]
best = 0;
for k = 1:size(opts.Monitors, 1)
    m = opts.Monitors(k, :);
    w = min(pos(1) + pos(3), m(1) + m(3)) - max(pos(1), m(1));
    h = min(pos(2) + pos(4), m(2) + m(4)) - max(pos(2), m(2));
    if w > 0 && h > 0 && w * h > best
        best = w * h;
        r = m;   % the monitor that holds most of the window
    end
end
side = 10;                % room left and right
below = 50;               % the taskbar
above = 80;               % the title bar, menus and toolbar
x0 = r(1) - 1;            % the screen's own left and bottom edges (the primary's origin is [1 1])
y0 = r(2) - 1;
pos(3) = min(pos(3), max(1, r(3) - 2 * side));
pos(4) = min(pos(4), max(1, r(4) - below - above));
pos(1) = min(max(pos(1), x0 + side), max(x0 + side, x0 + r(3) - pos(3) - side));
pos(2) = min(max(pos(2), y0 + below), max(y0 + below, y0 + r(4) - pos(4) - above));
end
