function h = statText(ax, S, style, colors, labels, opts)
%statText  A trial panel's group tests as text in a corner of its axes: a line per test, in its series' color.
%   H = statText(AX, S, STYLE, COLORS, LABELS, Corner=) writes each test
%   of trialStats' S (S.test) with a p as one line, "Kruskal-Wallis p =
%   0.003" (p < 0.001: "p < 0.001"), as callMarks writes its marks: TeX,
%   each line in the color of its series (COLORS(per, :); a test across
%   the series in dark gray) and, with more than one series, named by it
%   (LABELS(per): "Hit: Rank-sum p = 0.04"). A p under the tests'
%   significance level (S.options.Alpha) is bold, any other plain. One
%   text object in normalized units (so the axes' limits do not move it),
%   inside the corner: "northwest" (default) or "northeast", tagged
%   "statText". H is empty when no test gave a p (test "none", or too few
%   values).
%
%   See also drawTrialDistPanel, trialStats, callMarks, drawSigBrackets.

arguments
    ax
    S (1,1) struct
    style (1,1) struct
    colors double = zeros(0, 3)
    labels string = strings(0, 1)
    opts.Corner (1,1) string {mustBeMember(opts.Corner, ["northwest" "northeast"])} = "northwest"
end
h = gobjects(0);
if ~isfield(S, 'test') || isempty(S.test); return; end
alpha = 0.05;
if isfield(S, 'options') && isfield(S.options, 'Alpha'); alpha = S.options.Alpha; end
many = numel(labels) > 1;
lines = strings(0, 1);
for t = reshape(S.test, 1, [])
    if t.name == "none" || ~isfinite(t.p); continue; end
    c = [0.25 0.25 0.25];
    name = "";
    if t.per >= 1 && t.per <= size(colors, 1); c = colors(t.per, :); end
    if many && t.per >= 1 && t.per <= numel(labels); name = texEscape(labels(t.per)) + ": "; end
    pt = pText(t.p);
    if t.p < alpha; pt = "{\bf " + pt + "}"; end
    lines(end+1, 1) = sprintf('\\color[rgb]{%.3f,%.3f,%.3f}', c) + name + texEscape(t.label) + " " + pt; %#ok<AGROW>
end
if isempty(lines); return; end
x = 0.02;
ha = 'left';
if opts.Corner == "northeast"; x = 0.98; ha = 'right'; end
h = tagPart(text(ax, x, 0.98, cellstr(lines), 'Units', 'normalized', 'HorizontalAlignment', ha, 'VerticalAlignment', 'top', ...
    'Interpreter', 'tex', 'FontSize', max(6, style.FontSize - 1), 'Clipping', 'off'), "statText");
end


function s = pText(p)
%pText  A p value as people read it: "p = 0.003", "p < 0.001".
if p < 0.001
    s = "p < 0.001";
else
    s = "p = " + string(sprintf('%.2g', p));
end
end


function s = texEscape(s)
%texEscape  Text as TeX prints it literally: \ _ ^ { } escaped.
s = regexprep(string(s), '([\\_\^\{\}])', '\\$1');
end
