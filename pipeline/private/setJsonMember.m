function txt = setJsonMember(txt, key, value, who)
%setJsonMember  The text of a JSON object with one top-level member's value replaced.
%   TXT = setJsonMember(TXT, KEY, VALUE, WHO) writes VALUE (anything
%   jsonencode takes; pretty-printed, its lines after the first indented
%   one level) as the value of the top-level member KEY of the JSON object
%   TXT. A member that is not there is added after the last one. Nothing
%   else in TXT is touched: it is not decoded, so a null stays null and a
%   list of one stays a list. The text is read as its strings and brackets
%   (a string may hold any of the others), counting the depth. WHO is the
%   caller's name: TXT that is not a JSON object errors <WHO>:Unreadable.
%
%   See also addToManifest, writeManifestTags.
valueText = strrep(jsonencode(value, 'PrettyPrint', true), newline, [newline '    ']);
[tok, st, en] = regexp(txt, '"(?:[^"\\]|\\.)*"|[{}\[\],:]', 'match', 'start', 'end');
if isempty(tok)
    error([who ':Unreadable'], 'The manifest is not a JSON object.');
end
c = cellfun(@(t) t(1), tok);
after = cumsum((c == '{' | c == '[') - (c == '}' | c == ']'));
before = [0, after(1:end-1)];
isKey = c == '"' & before == 1 & [c(2:end) == ':', false] & strcmp(tok, ['"' key '"']);
ki = find(isKey, 1);
if ~isempty(ki)
    a = en(ki + 1) + find(~isspace(txt(en(ki + 1) + 1:end)), 1);   % where the value starts
    j = ki + 1 + find(before(ki + 2:end) == 1 & (c(ki + 2:end) == ',' | c(ki + 2:end) == '}'), 1);
    b = find(~isspace(txt(1:st(j) - 1)), 1, 'last');                % where it ends
    txt = [txt(1:a - 1), valueText, txt(b + 1:end)];
else
    close = find(c == '}' & before == 1 & after == 0, 1);
    p = find(~isspace(txt(1:st(close) - 1)), 1, 'last');            % the last member's end
    sep = ',';
    if txt(p) == '{'; sep = ''; end
    txt = [txt(1:p), sep, newline, '    "', key, '": ', valueText, txt(p + 1:end)];
end
end
