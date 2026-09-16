function v = parseOrderedList(txt, what)
%parseOrderedList  "1-4, 8, 12-10" -> [1 2 3 4 8 12 11 10].
%   Order and repeats are preserved (unlike EphysDataset.parseChannelList,
%   which sorts) because keepAmpChannels and channelRemap are order-sensitive.
%   A descending range (12-10) counts down. Anything unparseable is an error
%   (EphysPipelineConfig:SignalsIndexList), never silently dropped.
arguments
    txt = ""
    what (1,1) string = "Channel list"
end
v = double.empty(1, 0);
if isnumeric(txt)
    v = reshape(double(txt), 1, []);
    return
end
t = strtrim(char(string(txt)));
if isempty(t); return; end
t = regexprep(t, '\s*([-:])\s*', '$1');   % "5 - 8" -> "5-8"
toks = regexp(t, '[,;\s]+', 'split');
toks = toks(~cellfun(@isempty, toks));
for k = 1:numel(toks)
    mOne   = regexp(toks{k}, '^(\d+)$', 'tokens', 'once');
    mRange = regexp(toks{k}, '^(\d+)[-:](\d+)$', 'tokens', 'once');
    if ~isempty(mOne)
        a = str2double(mOne{1});
        b = a;
    elseif ~isempty(mRange)
        a = str2double(mRange{1});
        b = str2double(mRange{2});
    else
        error('EphysPipelineConfig:SignalsIndexList', ...
            '%s: cannot parse "%s". Use 1-based integers and ranges, e.g. 1-16, 20, 32-17.', ...
            what, toks{k});
    end
    if a < 1 || b < 1
        error('EphysPipelineConfig:SignalsIndexList', ...
            '%s: channel indices are 1-based ("%s").', what, toks{k});
    end
    if b >= a
        v = [v, a:b]; %#ok<AGROW>
    else
        v = [v, a:-1:b]; %#ok<AGROW>
    end
end
end
