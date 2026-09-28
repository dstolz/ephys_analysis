function applyMateEdit(obj, k, column, value)
%applyMateEdit  Change package connector K's mate: "Headstage", "HSConnector", "Orientation" or "Offset".
%   Headstage and HSConnector take the table's labels ("#2 RHD2132-32ch",
%   "top"; "(none)" unplugs it). An orientation change on a package whose
%   connectors all go to one headstage re-pairs them all
%   (ChannelMap.defaultMates: rotated pairs top with bottom); otherwise only
%   that connector turns. Then the table is rebuilt and the chain resolved.
b = obj.Bank;
if obj.PackageId == "" || ~b.has(obj.PackageId) || obj.HeadstageId == "" || ~b.has(obj.HeadstageId)
    return
end
pkg = b.get(obj.PackageId);
hs = b.get(obj.HeadstageId);
if k < 1 || k > numel(pkg.Faces)
    error('ChannelMapperApp:BadMate', 'Package %s has no connector %d.', pkg.Name, k);
end
from = "package:" + pkg.Faces(k).Id;
m = find(strsOf(obj.Mates, 'From') == from, 1);
[i, face] = parseTo(obj, m);
value = string(value);

switch column
    case "Headstage"
        if value == "(none)"
            obj.Mates(m) = [];
        else
            i = str2double(extractBetween(value, "#", " "));
            hsFaces = strsOf(hs.Faces, 'Id');
            if face == "" || ~any(hsFaces == face)
                used = strsOf(obj.Mates, 'To');
                free = hsFaces(~ismember(sprintf("headstage[%d]:", i) + hsFaces, used));
                if isempty(free); free = hsFaces; end
                face = free(1);
            end
            setMate(obj, m, from, i, face);
        end
    case "HSConnector"
        if value == "(none)"
            obj.Mates(m) = [];
        else
            if isnan(i); i = 1; end
            setMate(obj, m, from, i, value);
        end
    case "Orientation"
        to = strsOf(obj.Mates, 'To');
        inst = extractBefore(to, "]:");
        if numel(obj.Mates) > 1 && numel(unique(inst)) == 1 && numel(pkg.Faces) > 1
            i1 = str2double(extractAfter(inst(1), "["));
            pairs = ChannelMap.defaultMates(pkg.Faces, hs.Faces, value);
            obj.Mates = struct('From', {}, 'To', {}, 'Orientation', {});
            for p = 1:size(pairs, 1)
                obj.Mates(p) = struct('From', "package:" + pkg.Faces(pairs(p, 1)).Id, ...
                    'To', sprintf("headstage[%d]:%s", i1, hs.Faces(pairs(p, 2)).Id), 'Orientation', value);
            end
        elseif ~isempty(m)
            obj.Mates(m).Orientation = value;
        end
    case "Offset"
        if ~isnan(i)
            obj.Offsets(i) = double(value);
        end
end
obj.refreshMatesTable();
obj.resolve();
end


function [i, face] = parseTo(obj, m)
%parseTo  Headstage instance and face of mate M (NaN / "" when there is none).
i = NaN;
face = "";
if isempty(m)
    return
end
tok = regexp(obj.Mates(m).To, '^headstage\[(\d+)\]:(.+)$', 'tokens', 'once');
if ~isempty(tok)
    i = str2double(tok(1));
    face = tok(2);
end
end


function setMate(obj, m, from, i, face)
%setMate  Point mate M (a new one when empty) at headstage[i]:face.
to = sprintf("headstage[%d]:%s", i, face);
if isempty(m)
    obj.Mates(end + 1) = struct('From', from, 'To', to, 'Orientation', "reference");
else
    obj.Mates(m).To = to;
end
end
