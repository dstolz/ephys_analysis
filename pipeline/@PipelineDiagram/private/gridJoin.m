function h = gridJoin(parts)
%gridJoin  Concatenate a cell array of HTML strings.
h = join([string.empty(1, 0), parts{:}], "");
if isempty(h); h = ""; end
end


