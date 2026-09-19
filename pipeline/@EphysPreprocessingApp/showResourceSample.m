function showResourceSample(obj, S)
%showResourceSample  Show one resource_monitor.ps1 sample in the Resource use panel.
%   S is the decoded sample.json ([] clears the panel). Each bar is the
%   percentage in use, turning orange at 90 %; the text beside it gives the
%   figures, and its tooltip the detail. The disk bar is the busiest
%   physical disk's active time; the GPU bar is the busiest GPU.

bars = obj.RunMonitorBars;
texts = obj.RunMonitorTexts;
if isempty(S)
    for k = 1:numel(bars)
        setBar(obj, bars(k), 0);
        texts(k).Text = "";
        texts(k).Tooltip = "";
    end
    return
end

% --- CPU ---
cpu = num(S, 'cpu');
setBar(obj, bars(1), cpu / 100);
texts(1).Text = pct(cpu);
texts(1).Tooltip = "All cores, as Task Manager counts them.";

% --- memory ---
used = num(S, 'memUsedGB'); total = num(S, 'memTotalGB');
setBar(obj, bars(2), used / total);
texts(2).Text = sprintf("%.1f / %.1f GB", used, total);
texts(2).Tooltip = sprintf("Physical memory in use: %s of %.1f GB.", pct(100 * used / total), total);

% --- disk ---
disk = num(S, 'disk'); rd = num(S, 'readMBs'); wr = num(S, 'writeMBs');
setBar(obj, bars(3), disk / 100);
texts(3).Text = sprintf("%s  %s MB/s", pct(disk), fmt(rd + wr));
texts(3).Tooltip = sprintf("Busiest disk: %s, %s active. All disks: read %s MB/s, write %s MB/s.", ...
    string(S.diskName), pct(disk), fmt(rd), fmt(wr));

% --- GPU ---
g = [];
if isfield(S, 'gpus') && isstruct(S.gpus); g = S.gpus; end
if isempty(g)
    setBar(obj, bars(4), 0);
    texts(4).Text = "n/a";
    note = "no GPU reading";
    if isfield(S, 'gpuNote') && string(S.gpuNote) ~= ""; note = string(S.gpuNote); end
    texts(4).Tooltip = "GPU use is read with nvidia-smi: " + note + ".";
else
    util = arrayfun(@(x) num(x, 'util'), g);
    [~, b] = max(util);
    setBar(obj, bars(4), util(b) / 100);
    texts(4).Text = sprintf("%s  %.1f/%.1f GB", pct(util(b)), num(g(b), 'memUsedMB') / 1024, num(g(b), 'memTotalMB') / 1024);
    lines = strings(1, numel(g));
    for k = 1:numel(g)
        lines(k) = sprintf("GPU %d %s: %s, memory %.0f of %.0f MB", g(k).index, string(g(k).name), ...
            pct(util(k)), num(g(k), 'memUsedMB'), num(g(k), 'memTotalMB'));
    end
    texts(4).Tooltip = join(lines, newline);
end
obj.RunMonitorNote.Text = "Sampled every " + obj.ResourceMonitor.interval + " s outside MATLAB; last at " + ...
    string(datetime(S.t, "InputFormat", "yyyy-MM-dd'T'HH:mm:ss"), "HH:mm:ss") + ".";
end


function setBar(obj, bar, frac)
%setBar  setRunBar, with the fill orange from 90 %.
if ~isfinite(frac); frac = 0; end
obj.setRunBar(bar, frac);
fill = bar.Children;
if isempty(fill); return; end
if frac >= 0.9
    fill(1).BackgroundColor = [0.9 0.45 0.1];
else
    fill(1).BackgroundColor = [0.25 0.55 0.85];
end
end


function v = num(S, field)
%num  A numeric field of the sample, NaN when missing or null.
v = NaN;
if isfield(S, field) && isnumeric(S.(field)) && isscalar(S.(field))
    v = double(S.(field));
end
end


function s = pct(v)
if isfinite(v); s = sprintf("%.0f%%", v); else; s = "n/a"; end
end


function s = fmt(v)
if ~isfinite(v); s = "n/a"; elseif v < 10; s = sprintf("%.1f", v); else; s = sprintf("%.0f", v); end
end
