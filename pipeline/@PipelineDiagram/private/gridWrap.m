function out = gridWrap(lines, maxW, px)
%gridWrap  Break each line at spaces to fit MAXW pixels (at PX font size);
%   a word too long for a line of its own breaks after a _ - / . where it can.
out = strings(1, 0);
for s = reshape(string(lines), 1, [])
    cur = "";
    for word = reshape(split(s, " "), 1, [])
        cand = ternary(cur == "", word, cur + " " + word);
        if gridTextWidth(cand, px) <= maxW
            cur = cand;
            continue
        end
        if cur ~= ""; out(end+1) = cur; end %#ok<AGROW>
        rest = word;
        while gridTextWidth(rest, px) > maxW
            [head, rest] = breakWord(rest, maxW, px);
            out(end+1) = head; %#ok<AGROW>
        end
        cur = rest;
    end
    if cur ~= ""; out(end+1) = cur; end %#ok<AGROW>
end
end


function [head, rest] = breakWord(w, maxW, px)
c = char(w);
n = 1;
while n < numel(c) && gridTextWidth(c(1:n + 1), px) <= maxW
    n = n + 1;
end
cut = find(ismember(c(1:n), '_-/.\'), 1, "last");
if ~isempty(cut) && cut > n / 2; n = cut; end
head = string(c(1:n));
rest = string(c(n + 1:end));
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
