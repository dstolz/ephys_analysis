function [values, names, ok] = parseNameTokens(name, pattern)
%parseNameTokens  Extract named tokens from a dataset / file name.
%   [VALUES, NAMES, OK] = parseNameTokens(NAME, PATTERN) matches the whole
%   NAME (a file stem, no extension) against PATTERN and returns the token
%   names (string row, in pattern order), their text VALUES (string row, ""
%   when NAME does not match) and whether it matched.
%
%   PATTERN is literal text with tokens in braces:
%     {Token}          any text (as short as possible)
%     {Token:yyMMdd}   a datetime-style format made only of the letters
%                      y M d H h m s: that many digits
%     {Token:regex}    any other format is used as a regular expression
%     *                any text that is not kept (e.g. a trailing suffix)
%   Token names must be valid MATLAB identifiers and unique.
%
%   Default (Project.NamePattern): "{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"
%   splits "SUBJ-ID-1245_260916_143015" into SubjectID = "SUBJ-ID-1245",
%   Date = "260916", Time = "143015".
%
%   NAMES = parseNameTokens("", PATTERN) just lists the tokens; an invalid
%   pattern throws parseNameTokens:BadPattern.

arguments
    name (1,1) string
    pattern (1,1) string
end

[expr, names] = compilePattern(pattern);
values = strings(1, numel(names));
ok = false;
if isempty(names)
    return
end
tok = regexp(name, expr, 'tokens', 'once');
if ~isempty(tok)
    ok = true;
    values = string(tok);
end
end


function [expr, names] = compilePattern(pattern)
names = string.empty(1, 0);
expr = "^";
p = char(pattern);
i = 1;
lit = '';
while i <= numel(p)
    c = p(i);
    if c == '{'
        j = find(p(i+1:end) == '}', 1);
        if isempty(j)
            bad(pattern, "unclosed ""{""");
        end
        body = strtrim(p(i+1:i+j-1));
        i = i + j + 1;
        expr = expr + regexptranslate('escape', lit);
        lit = '';
        k = find(body == ':', 1);
        if isempty(k)
            tname = string(body); fmt = "";
        else
            tname = string(strtrim(body(1:k-1))); fmt = string(strtrim(body(k+1:end)));
        end
        if ~isvarname(tname)
            bad(pattern, sprintf("token name ""%s"" is not a valid identifier", tname));
        end
        if any(names == tname)
            bad(pattern, sprintf("token ""%s"" appears twice", tname));
        end
        names(end+1) = tname; %#ok<AGROW>
        if fmt == ""
            expr = expr + "(.+?)";
        elseif ~isempty(regexp(fmt, '^[yMdHhms]+$', 'once'))
            expr = expr + sprintf("(\\d{%d})", strlength(fmt));
        else
            try
                regexp("", fmt, 'once');
            catch ME
                bad(pattern, sprintf("token ""%s"": %s", tname, ME.message));
            end
            expr = expr + "(" + stripCaptures(fmt) + ")";
        end
    elseif c == '}'
        bad(pattern, "unmatched ""}""");
    elseif c == '*'
        expr = expr + regexptranslate('escape', lit) + ".*?";
        lit = '';
        i = i + 1;
    else
        lit(end+1) = c; %#ok<AGROW>
        i = i + 1;
    end
end
expr = expr + regexptranslate('escape', lit) + "$";
end


function s = stripCaptures(fmt)
%stripCaptures  Make plain groups in a user regex non-capturing so token
%   positions stay aligned with the pattern's tokens.
s = regexprep(fmt, '(?<!\\)\((?!\?)', '(?:');
s = regexprep(s, '(?<!\\)\(\?<[A-Za-z]\w*>', '(?:');
end


function bad(pattern, why)
error('parseNameTokens:BadPattern', 'Invalid name pattern "%s": %s.', pattern, why);
end
