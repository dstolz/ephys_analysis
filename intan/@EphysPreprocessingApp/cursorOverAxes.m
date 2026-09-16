function tf = cursorOverAxes(obj)
    % True when the pointer is inside the Visualize axes (pixel coords).
    pp = getpixelposition(obj.VizAxes, true);
    cp = obj.Fig.CurrentPoint;
    tf = cp(1) >= pp(1) && cp(1) <= pp(1) + pp(3) ...
        && cp(2) >= pp(2) && cp(2) <= pp(2) + pp(4);
end
