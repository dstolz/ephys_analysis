function pos = fitToScreen(pos)
%fitToScreen  A figure position that fits the primary screen.
%   POS = fitToScreen(POS) shrinks POS ([x y width height], pixels, as a
%   figure's Position) to the screen less room for the title bar, menus and
%   the taskbar, then moves it so the whole window is on screen. A position
%   that already fits is returned unchanged. Used for a window's saved or
%   default position, which may come from a larger display or another layout.
r = groot().ScreenSize;   % [x y w h]
side = 10;                % room left and right
below = 50;               % the taskbar
above = 80;               % the title bar, menus and toolbar
pos(3) = min(pos(3), max(1, r(3) - 2 * side));
pos(4) = min(pos(4), max(1, r(4) - below - above));
pos(1) = min(max(pos(1), side), max(side, r(3) - pos(3) - side));
pos(2) = min(max(pos(2), below), max(below, r(4) - pos(4) - above));
end
