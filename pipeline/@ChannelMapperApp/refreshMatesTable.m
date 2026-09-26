function refreshMatesTable(obj)
%refreshMatesTable  One row per package connector: its headstage, connector, orientation, offset.
%   Headstage, HS connector and Orientation are categorical, so the cells
%   are dropdowns; a package connector without a mate shows "(none)".
%   Rebuilt from the chain's state, so call it after the state changes,
%   not while the user edits.
obj.Applying = true;
c = onCleanup(@() resetFlag(obj, 'Applying'));
b = obj.Bank;
names = {'Probe connector', 'Headstage', 'HS connector', 'Orientation', 'Ch offset'};
if obj.PackageId == "" || ~b.has(obj.PackageId)
    obj.MatesTable.Data = table(strings(0, 1), categorical(strings(0, 1)), categorical(strings(0, 1)), ...
        categorical(strings(0, 1)), zeros(0, 1), 'VariableNames', names);
    return
end
pkg = b.get(obj.PackageId);
hsLabels = "(none)";
faceIds = "(none)";
if obj.HeadstageId ~= "" && b.has(obj.HeadstageId)
    hs = b.get(obj.HeadstageId);
    hsLabels = ["(none)", compose("#%d ", 1:obj.HeadstageCount) + hs.Name];
    faceIds = ["(none)", strsOf(hs.Faces, 'Id')];
end
n = numel(pkg.Faces);
hsCol = repmat("(none)", n, 1);
faceCol = repmat("(none)", n, 1);
oriCol = repmat("reference", n, 1);
offCol = NaN(n, 1);
from = strsOf(obj.Mates, 'From');
for f = 1:n
    m = find(from == "package:" + pkg.Faces(f).Id, 1);
    if isempty(m)
        continue
    end
    tok = regexp(obj.Mates(m).To, '^headstage\[(\d+)\]:(.+)$', 'tokens', 'once');
    oriCol(f) = obj.Mates(m).Orientation;
    if isempty(tok)
        continue
    end
    i = str2double(tok(1));
    if i >= 1 && i < numel(hsLabels)
        hsCol(f) = hsLabels(i + 1);
        offCol(f) = obj.Offsets(i);
    end
    if any(faceIds == tok(2))
        faceCol(f) = tok(2);
    end
end
obj.MatesTable.Data = table(strsOf(pkg.Faces, 'Id')', categorical(hsCol, hsLabels), ...
    categorical(faceCol, faceIds), categorical(oriCol, ChannelMap.Orientations), offCol, ...
    'VariableNames', names);
end
