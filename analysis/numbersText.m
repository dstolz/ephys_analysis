function s = numbersText(v)
%numbersText  Numbers as a field shows them: each run of 3 or more whole numbers as "a:b" ("1:16 33:48", "1:4 7"), the rest "1 3"; "" for none.
%   S = numbersText(V) writes the row V as text that parseNumbers reads
%   back to V, in V's order: a run of 3 or more consecutive whole numbers
%   as "a:b", every other value as itself, apart by spaces ("1 3 7",
%   "0.5 2", "1:4 7"). [] gives "" (a blank field: all).
%
%   See also parseNumbers, DatasetBrowser, ProbePickDialog.
v = reshape(double(v), 1, []);
s = "";
if isempty(v); return; end
parts = strings(1, 0);
i = 1;
n = numel(v);
while i <= n
    j = i;
    while j < n && v(j) == round(v(j)) && v(j + 1) == v(j) + 1
        j = j + 1;
    end
    if j - i >= 2   % a run of 3 or more
        parts(end+1) = sprintf("%g:%g", v(i), v(j)); %#ok<AGROW>
    else
        parts = [parts compose("%g", v(i:j))]; %#ok<AGROW>
    end
    i = j + 1;
end
s = strjoin(parts, " ");
end
