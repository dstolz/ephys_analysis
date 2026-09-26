function v = strsOf(S, name)
%strsOf  A string field of every element of a struct array, as a row (empty for none).
v = strings(1, numel(S));
for k = 1:numel(S)
    v(k) = S(k).(name);
end
end
