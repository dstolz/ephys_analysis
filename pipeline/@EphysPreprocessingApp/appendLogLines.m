function appendLogLines(obj, lines)
    % Append a block of pre-formatted lines to the Kilosort log area in
    % a single update (cheaper than calling log() per line when tailing
    % a run's ks4_run.log). Empty input is a no-op.
    lines = cellstr(string(lines(:)));
    if isempty(lines); return; end
    cur = obj.KSLogArea.Value;
    if isscalar(cur) && strlength(string(cur{1})) == 0
        cur = cell(0, 1);   % drop the default blank line
    end
    obj.KSLogArea.Value = [cur; lines];
    scroll(obj.KSLogArea, 'bottom');
    drawnow limitrate;
end
