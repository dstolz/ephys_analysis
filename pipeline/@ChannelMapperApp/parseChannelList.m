function v = parseChannelList(txt)
%parseChannelList  "0-15, 17, 20:23" -> [0 1 ... 15 17 20 21 22 23].
%   Items are separated by commas, semicolons or spaces; an item is a
%   whole number, a range a-b or a:b (descending when b < a), or a:step:b.
%   Errors ChannelMapperApp:BadList.
v = zeros(1, 0);
items = string(regexp(strtrim(string(txt)), '[\s,;]+', 'split'));
items(items == "") = [];
for it = items
    parts = split(it, ["-", ":"]);
    ok = ~any(parts == "") && all(~cellfun(@isempty, regexp(cellstr(parts), '^\d+$', 'once')));
    if ~ok || numel(parts) > 3
        error('ChannelMapperApp:BadList', 'Not a channel or a range: "%s" (use e.g. 0-15, 17, 20:23).', it);
    end
    n = str2double(parts);
    switch numel(n)
        case 1
            v(end + 1) = n; %#ok<AGROW>
        case 2
            step = 1;
            if n(2) < n(1); step = -1; end
            v = [v, n(1):step:n(2)]; %#ok<AGROW>
        case 3
            v = [v, n(1):n(2):n(3)]; %#ok<AGROW>
    end
end
if isempty(v)
    error('ChannelMapperApp:BadList', 'The channel list is empty.');
end
if numel(unique(v)) ~= numel(v)
    error('ChannelMapperApp:BadList', 'A channel is listed twice.');
end
end
