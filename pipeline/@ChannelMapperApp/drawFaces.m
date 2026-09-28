function drawFaces(obj)
%drawFaces  Each package connector over the headstage connector it mates with.
%   The package face (male) is drawn as its vendor drawing shows it; the
%   headstage face (female) under it is drawn already mirrored into the
%   package's frame (ChannelMapperApp.drawFace, Mirror = the orientation),
%   so pins that touch share a column, and flipping the orientation
%   visibly flips the lower face. The first package face's rows are at
%   y = 1..R, x = 1..C. obj.FaceDraw keeps, per drawn face, its key
%   ("package:<face>" or "headstage[i]:<face>"), patch, base colours and
%   frame, for clicks and highlighting.
ax = obj.MateAxes;
cla(ax);
hold(ax, 'on');
obj.FaceDraw = struct('Key', {}, 'Patch', {}, 'Base', {}, 'Rows', {}, 'Cols', {}, 'Origin', {}, 'Mirror', {});
R = obj.Result;
if isempty(R)
    hold(ax, 'off');
    text(ax, 0.5, 0.5, 'Choose a package and a headstage', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'Color', [0.45 0.45 0.45], 'FontSize', 12, 'HitTest', 'off');
    return
end
chain = R.Chain;
pkg = chain.package;
y0 = 0;
maxC = 1;
drawnHs = strings(0, 1);
for f = 1:numel(pkg.Faces)
    up = pkg.Faces(f);
    key = "package:" + up.Id;
    [nR, nC] = size(up.Cells);
    maxC = max(maxC, nC);
    h = ChannelMapperApp.drawFace(ax, up, Origin=[0 y0], ...
        Caption=sprintf("%s %s (male, looking into the pins, printed side up)", pkg.Name, up.Id), ...
        ButtonDownFcn=@(~, evt) obj.onFaceClick(key, evt));
    add(obj, key, h);
    m = find(arrayfun(@(x) isequal(x.PkgFace, f), R.Mates), 1);
    if ~isempty(m) && isfinite(R.Mates(m).HsIndex)
        mi = R.Mates(m);
        hsE = chain.headstages(mi.HsIndex).Entry;
        dn = hsE.Faces(mi.HsFace);
        hkey = sprintf("headstage[%d]:%s", mi.HsIndex, dn.Id);
        label = hsE.Name;
        if numel(chain.headstages) > 1
            label = label + " #" + mi.HsIndex;
        end
        yf = y0 + nR + 1.7;
        h2 = ChannelMapperApp.drawFace(ax, dn, Origin=[0 yf], Mirror=mi.Orientation, ...
            Caption=sprintf("%s %s (female, drawn mirrored to meet it: %s)", label, dn.Id, mi.Orientation), ...
            ButtonDownFcn=@(~, evt) obj.onFaceClick(hkey, evt));
        add(obj, hkey, h2);
        drawnHs(end + 1) = hkey; %#ok<AGROW>
        y0 = yf + size(dn.Cells, 1) + 1.9;
    else
        text(ax, 0.55, y0 + nR + 1.1, '(not mated to a headstage connector)', 'FontSize', 9, ...
            'Color', [0.75 0 0], 'HitTest', 'off');
        y0 = y0 + nR + 2.2;
    end
end
% headstage connectors nothing plugs into
for i = 1:numel(chain.headstages)
    hsE = chain.headstages(i).Entry;
    for f = 1:numel(hsE.Faces)
        hkey = sprintf("headstage[%d]:%s", i, hsE.Faces(f).Id);
        if any(drawnHs == hkey); continue; end
        label = hsE.Name;
        if numel(chain.headstages) > 1
            label = label + " #" + i;
        end
        maxC = max(maxC, size(hsE.Faces(f).Cells, 2));
        h = ChannelMapperApp.drawFace(ax, hsE.Faces(f), Origin=[0 y0], ...
            Caption=sprintf("%s %s (female, looking into it; nothing plugged in)", label, hsE.Faces(f).Id), ...
            ButtonDownFcn=@(~, evt) obj.onFaceClick(hkey, evt));
        add(obj, hkey, h);
        y0 = y0 + size(hsE.Faces(f).Cells, 1) + 1.9;
    end
end
hold(ax, 'off');
ax.YDir = 'reverse';
axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [0.3, maxC + 0.7]);
ylim(ax, [-0.6, max(y0 - 1, 3)]);
end


function add(obj, key, h)
obj.FaceDraw(end + 1) = struct('Key', string(key), 'Patch', h.Patch, 'Base', h.Base, 'Rows', h.Rows, ...
    'Cols', h.Cols, 'Origin', h.Origin, 'Mirror', h.Mirror);
end
