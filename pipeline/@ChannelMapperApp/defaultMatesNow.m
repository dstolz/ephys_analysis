function defaultMatesNow(obj)
%defaultMatesNow  Default mates and channel offsets for the chosen package and headstages.
%   Each package face takes the first free headstage face of its connector
%   (ChannelMap.defaultMates, reference). Headstage instance i gets the
%   offset (i-1) * (its highest channel + 1): a second RHD2132 counts on
%   from 32, as the recording software numbers a second port.
b = obj.Bank;
obj.Mates = struct('From', {}, 'To', {}, 'Orientation', {});
n = max(1, round(obj.HeadstageCount));
obj.HeadstageCount = n;
if obj.HeadstageId == "" || ~b.has(obj.HeadstageId)
    obj.Offsets = zeros(1, n);
    return
end
hs = b.get(obj.HeadstageId);
top = 0;
for f = 1:numel(hs.Faces)
    v = str2double(hs.Faces(f).Cells(:));
    top = max([top; v(isfinite(v))]);
end
obj.Offsets = (0:n - 1) * (top + 1);
if obj.PackageId == "" || ~b.has(obj.PackageId)
    return
end
pkg = b.get(obj.PackageId);
down = repmat(hs.Faces(:), n, 1);
dev = repelem(1:n, numel(hs.Faces));
names = strings(numel(down), 1);
for k = 1:numel(down)
    names(k) = sprintf("headstage[%d]:%s", dev(k), down(k).Id);
end
pairs = ChannelMap.defaultMates(pkg.Faces, down, "reference", dev);
for k = 1:size(pairs, 1)
    obj.Mates(k) = struct('From', "package:" + pkg.Faces(pairs(k, 1)).Id, 'To', names(pairs(k, 2)), ...
        'Orientation', "reference");
end
end
