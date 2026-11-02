function showTabReason(obj)
%showTabReason  Say in the status bar why the selected tab is amber or red.
%   The tab strip colors a tab by its status and writes a glyph after its
%   name ("Probe !", "Run x": syncTabStrip), so the color is not the only
%   sign. While the selected tab has a problem, the status bar's right side
%   reads "! <first reason>" (amber) or "x <first reason>" (red) in place of
%   the suggested next step, with every reason in its tooltip. A hint a
%   caller gave on purpose (setStatus) stays, and once the problem is gone
%   the suggested next step returns.
%
%   See also syncTabStrip, setStatus, suggestNextStep.
h = obj.StatusHint;
if isempty(h) || ~isvalid(h); return; end
why = "";
full = "";
state = "";
k = [];
if ~isempty(obj.TabState) && ~isempty(obj.Tabs) && isvalid(obj.Tabs)
    k = find(obj.TabList == obj.Tabs.SelectedTab, 1);
end
if ~isempty(k) && k <= numel(obj.TabState) && ismember(obj.TabState(k), ["warn" "error"])
    state = obj.TabState(k);
    full = obj.TabReason(k);
    lines = splitlines(full);
    why = strtrim(lines(1));
    if strlength(why) > 110; why = extractBefore(why, 108) + "..."; end
end
if why ~= "" && string(h.Tag) ~= "explicit"
    if state == "error"
        h.Text = char("x " + why);
        h.FontColor = [0.75 0.15 0.10];
    else
        h.Text = char("! " + why);
        h.FontColor = [0.65 0.40 0.00];
    end
    h.Tooltip = char(full);
    h.Tag = "reason";
elseif string(h.Tag) == "reason"   % the problem is gone: the next step again
    hint = obj.suggestNextStep();
    if strlength(hint) == 0
        h.Text = "";
    else
        h.Text = char("Next: " + hint);
    end
    h.Tooltip = char(hint);
    h.FontColor = [0.15 0.45 0.75];
    h.Tag = "";
end
end
