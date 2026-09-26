function loadPreferences(obj)
%loadPreferences  Restore the window's position (kept on screen).
%   Preferences (group ChannelMapperApp): FigurePosition, BankFolder (read
%   by the constructor) and LastChain (restoreLastChain).
g = obj.PrefGroup;
if ispref(g, 'FigurePosition')
    pos = getpref(g, 'FigurePosition');
    if isnumeric(pos) && numel(pos) == 4 && all(pos(3:4) > 100)
        obj.Fig.Position = clampToScreen(pos);
    end
end
end


function pos = clampToScreen(pos)
%clampToScreen  Keep the figure on-screen if the display layout changed.
try
    r = groot().ScreenSize;   % [x y w h]
    pos(1) = min(max(pos(1), 1), max(1, r(3) - 100));
    pos(2) = min(max(pos(2), 1), max(1, r(4) - 100));
    pos(3) = min(pos(3), r(3));
    pos(4) = min(pos(4), r(4));
catch
end
end
