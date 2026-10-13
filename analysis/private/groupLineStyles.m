function ls = groupLineStyles(R)
%groupLineStyles  Each group's line style: R.groups.lineStyle, else "-" for every group.
%   A result merged across sessions with TrialGroups "combine"
%   (combineSessions) tells its trial groups apart by line style, its
%   sessions by color. LS: [nGroups x 1] string.
n = height(R.groups);
ls = repmat("-", n, 1);
if ismember("lineStyle", string(R.groups.Properties.VariableNames))
    v = reshape(string(R.groups.lineStyle), [], 1);
    ok = ismember(v, ["-" "--" ":" "-."]);
    ls(ok) = v(ok);
end
end
