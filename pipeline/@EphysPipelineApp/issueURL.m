function [url, truncated] = issueURL(obj, kind, title, body)
%issueURL  Address of a prefilled "new issue" form on GitHub.
%   URL = issueURL(OBJ, KIND, TITLE, BODY) builds the address the Help
%   menu's issue items open (see onReportIssue): the repository's new-issue
%   form (EphysPreprocessingApp.RepoURL) with the title, the report and the
%   label filled in. KIND is "bug" (label "bug") or "feature" (label
%   "enhancement"). Nothing is filed: the form opens in the browser for the
%   user to read and submit.
%
%   [URL, TRUNCATED] = ... also says whether BODY had to be cut. GitHub
%   rejects an address beyond roughly 8 kB, so a longer report is cut at a
%   line boundary and the cut is stated in the body itself; the caller
%   leaves the whole report on the clipboard. Nothing else is changed: what
%   is sent is the report as issueReport wrote it, up to the cut.
arguments
    obj (1,1) EphysPreprocessingApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    title (1,1) string = ""
    body (1,1) string = ""
end
maxURL = 7000;   % the address bar and GitHub's request line both hold about 8 kB

label = "bug";
if kind == "feature"; label = "enhancement"; end
base = obj.RepoURL + "/issues/new";

truncated = false;
url = formURL(base, title, body, label);
if strlength(url) <= maxURL; return; end

truncated = true;
note = newline + newline + "_The report was too long for the address bar and was cut here. " + ...
    "The whole report is on the clipboard: paste it in place of this line._";
chars = char(body);
% Start from what the overrun says will fit, then shrink until it does.
n = max(1, min(numel(chars), floor(numel(chars) * maxURL / strlength(url))));
while n > 0
    cut = char(chars(1:n));
    br = find(cut == newline, 1, 'last');       % end on a whole line
    if ~isempty(br) && br > 1; cut = cut(1:br - 1); end
    kept = string(cut);
    if mod(count(kept, "```"), 2) == 1          % the cut fell inside a code fence: close it
        kept = kept + newline + "```";
    end
    url = formURL(base, title, kept + note, label);
    if strlength(url) <= maxURL; return; end
    n = min(numel(cut), floor(n * 0.9));
end
url = formURL(base, title, strip(note), label);
end


function url = formURL(base, title, body, label)
%formURL  The new-issue form with its query filled in.
url = base + "?title=" + percentEncode(title) + "&body=" + percentEncode(body) + ...
    "&labels=" + percentEncode(label);
end


function s = percentEncode(txt)
%percentEncode  Percent-encode TXT (UTF-8) for a URL query value.
%   Everything outside the unreserved set of RFC 3986 is encoded, so spaces
%   and newlines survive as %20 and %0A rather than being reshaped.
b = double(unicode2native(char(txt), 'UTF-8'));
if isempty(b); s = ""; return; end
safe = (b >= 48 & b <= 57) | (b >= 65 & b <= 90) | (b >= 97 & b <= 122) | ismember(b, double('-._~'));
out = strings(numel(b), 1);
kept = char(b(safe));
out(safe) = string(kept(:));
out(~safe) = "%" + string(dec2hex(b(~safe), 2));
s = join(out, "");
end
