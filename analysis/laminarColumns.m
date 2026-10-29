function C = laminarColumns(channels, opts)
%laminarColumns  The laminar columns of a channel table: each shank's sites ordered top to bottom, with depths.
%   C = laminarColumns(CHANNELS) groups the rows of CHANNELS (a table with
%   x, y and shank in um, as selectChannels' META, R.rows of a signal
%   result or a session's D.channels) into the columns a current source
%   density is estimated along: a struct array, one per column, with
%     shank      the shank
%     x_um       the column's x position(s) on the shank, um
%     rows       the channels' rows of CHANNELS, from the top of the shank
%                (largest y) down
%     depth_mm   [n x 1] each channel's distance below the column's top
%                channel, mm, ascending (0 for the top one): the positions
%                the CSD toolboxes take
%     y_um       [n x 1] their y, um
%     h_mm       the spacing, mm (the median of the steps)
%     uniform    true when every step is within 1% of h_mm
%     label, channel   [n x 1] from CHANNELS (label, channel; when present)
%     dim        1 (positions are depths) or 2 (Columns="2d": x and depth)
%     pos_mm     [n x dim] the positions for a 2-D estimate: x from the
%                column's leftmost channel and depth, mm (dim 2), else
%                depth_mm
%   Channels without a position (NaN x or y) are left out, and columns of
%   fewer than MinChannels (default 3) channels are dropped. The columns
%   come in shank order, then by x.
%
%   Columns decides how a shank with several x positions is treated:
%     "auto" (default)  one column per shank when no two of its channels
%                       share a depth (a staggered design: the x offset is
%                       ignored and the depths interleave into one
%                       profile), else one column per x
%     "separate"        one column per x on each shank
%     "merged"          one column per shank, whatever the x
%     "2d"              one column per shank, dim 2: pos_mm is [x depth]
%   Shanks limits the shanks ([] = all). Tolerance (um, default 1) decides
%   when two channels share a depth or an x.
%
%   See also epochMatrixCSD, sessionDataCSD, icsdEstimate, kcsdEstimate.

arguments
    channels table
    opts.Columns (1,1) string {mustBeMember(opts.Columns, ["auto" "separate" "merged" "2d"])} = "auto"
    opts.Shanks double = []
    opts.MinChannels (1,1) double {mustBeInteger, mustBePositive} = 3
    opts.Tolerance (1,1) double {mustBePositive} = 1
end
need = ["x" "y"];
vars = string(channels.Properties.VariableNames);
if ~all(ismember(need, vars))
    error('laminarColumns:NoPositions', 'The channel table has no x and y columns (the probe positions).');
end
x = double(channels.x(:));
y = double(channels.y(:));
if ismember("shank", vars)
    shank = double(channels.shank(:));
else
    shank = ones(height(channels), 1);
end
shank(isnan(shank)) = 0;
placed = isfinite(x) & isfinite(y);
if ~isempty(opts.Shanks)
    placed = placed & ismember(shank, opts.Shanks(:));
end
tol = opts.Tolerance;

C = emptyColumns();
for s = unique(shank(placed)).'
    on = find(placed & shank == s);
    xs = uniquetol(x(on), tol, 'DataScale', 1);
    mode = opts.Columns;
    if mode == "auto"
        distinct = numel(uniquetol(y(on), tol, 'DataScale', 1)) == numel(on);
        if numel(xs) > 1 && ~distinct; mode = "separate"; else; mode = "merged"; end
    end
    if mode == "separate"
        groups = arrayfun(@(xv) on(abs(x(on) - xv) <= tol), xs(:).', 'UniformOutput', false);
    else
        groups = {on};
    end
    for g = groups
        rows = g{1};
        if numel(rows) < opts.MinChannels; continue; end
        [~, ord] = sortrows([-y(rows), x(rows), rows]);     % top down, then left to right
        rows = rows(ord);
        c = struct();
        c.shank = s;
        c.x_um = reshape(uniquetol(x(rows), tol, 'DataScale', 1), 1, []);
        c.rows = rows(:);
        c.y_um = y(rows);
        c.depth_mm = (y(rows(1)) - y(rows)) / 1000;
        steps = diff(c.depth_mm);
        steps = steps(steps > tol / 1000);                    % channels at one depth (two columns) are no step
        if isempty(steps)
            c.h_mm = NaN;
            c.uniform = false;
        else
            c.h_mm = median(steps);
            c.uniform = all(abs(steps - c.h_mm) <= 0.01 * c.h_mm);
        end
        c.label = columnOf(channels, "label", rows);
        c.channel = columnOf(channels, "channel", rows);
        if mode == "2d"
            c.dim = 2;
            c.pos_mm = [(x(rows) - min(x(rows))) / 1000, c.depth_mm];
        else
            c.dim = 1;
            c.pos_mm = c.depth_mm;
        end
        C(end + 1, 1) = c; %#ok<AGROW>
    end
end
end


function v = columnOf(T, name, rows)
if ismember(name, string(T.Properties.VariableNames))
    v = T.(name)(rows);
    if ischar(v) || iscellstr(v); v = string(v); end
    v = v(:);
else
    v = [];
end
end


function C = emptyColumns()
C = struct('shank', {}, 'x_um', {}, 'rows', {}, 'y_um', {}, 'depth_mm', {}, 'h_mm', {}, ...
    'uniform', {}, 'label', {}, 'channel', {}, 'dim', {}, 'pos_mm', {});
end
