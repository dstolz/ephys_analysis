function h = drawFace(ax, face, opts)
%drawFace  One connector face as a grid of labelled cells.
%   H = ChannelMapperApp.drawFace(AX, FACE, Origin=[x0 y0], Mirror=,
%   Caption=, ButtonDownFcn=, FontSize=) draws FACE (a ChannelMap face)
%   with cell (r, c) at x = x0 + c, y = y0 + r (row 1 on top when
%   AX.YDir is 'reverse'). Mirror draws a female face in its male mate's
%   frame, so mated pins share a column: "reference" puts (r, c) at
%   column N+1-c, "rotated" at row R+1-r; "none" draws it as it is.
%   One patch holds every cell (its FaceVertexCData row k colours cell k,
%   k = sub2ind([R C], r, c)); one text call writes the labels (numbers,
%   G, R, R1.., PR, nc); guide posts are hollow circles. H has fields
%   Patch, Labels, Base (the cell colours), Rows, Cols, Origin, Mirror.
arguments
    ax
    face (1,1) struct
    opts.Origin (1,2) double = [0 0]
    opts.Mirror (1,1) string {mustBeMember(opts.Mirror, ["none" "reference" "rotated"])} = "none"
    opts.Caption (1,1) string = ""
    opts.ButtonDownFcn = []
    opts.FontSize (1,1) double = 8
end
cells = face.Cells;
[nR, nC] = size(cells);
[rr, cc] = ndgrid(1:nR, 1:nC);
rr = rr(:); cc = cc(:);
switch opts.Mirror
    case "reference"
        dx = nC + 1 - cc; dy = rr;
    case "rotated"
        dx = cc; dy = nR + 1 - rr;
    otherwise
        dx = cc; dy = rr;
end
X = opts.Origin(1) + dx;
Y = opts.Origin(2) + dy;
n = numel(X);
s = 0.44;
V = zeros(4 * n, 2);
V(1:4:end, :) = [X - s, Y - s];
V(2:4:end, :) = [X + s, Y - s];
V(3:4:end, :) = [X + s, Y + s];
V(4:4:end, :) = [X - s, Y + s];
F = reshape(1:4 * n, 4, n)';

C = ChannelMapperApp.Colors;
v = cells(:);
cls = ChannelMap.cellClass(v);
base = repmat(C.signal, n, 1);
base(cls == "GND", :) = repmat(C.GND, nnz(cls == "GND"), 1);
isRef = cls == "REF" & v ~= "PR";
base(isRef, :) = repmat(C.REF, nnz(isRef), 1);
base(v == "PR", :) = repmat(C.PR, nnz(v == "PR"), 1);
base(cls == "NC", :) = repmat(C.NC, nnz(cls == "NC"), 1);
base(cls == "GUIDE", :) = repmat(C.GUIDE, nnz(cls == "GUIDE"), 1);

args = {};
if ~isempty(opts.ButtonDownFcn)
    args = {'ButtonDownFcn', opts.ButtonDownFcn};
end
p = patch(ax, 'Vertices', V, 'Faces', F, 'FaceVertexCData', base, 'FaceColor', 'flat', ...
    'EdgeColor', [0.55 0.6 0.7], 'LineWidth', 0.5, 'PickableParts', 'visible', args{:});

lab = v;
lab(v == "GND") = "G";
lab(v == "REF") = "R";
lab(startsWith(v, "REF") & strlength(v) == 4) = "R" + extractAfter(v(startsWith(v, "REF") & strlength(v) == 4), 3);
lab(v == "NC") = "nc";
lab(v == "GUIDE") = "";
show = lab ~= "";
t = text(ax, X(show), Y(show), lab(show), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', opts.FontSize, 'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'on');
g = cls == "GUIDE";
if any(g)
    line(ax, X(g), Y(g), 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 7, 'Color', [0.55 0.55 0.55], ...
        'HitTest', 'off', 'PickableParts', 'none');
end
if opts.Caption ~= ""
    text(ax, opts.Origin(1) + 0.55, opts.Origin(2) + 0.4, opts.Caption, 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none', 'HitTest', 'off', 'PickableParts', 'none');
end
h = struct('Patch', p, 'Labels', t, 'Base', base, 'Rows', nR, 'Cols', nC, 'Origin', opts.Origin, 'Mirror', opts.Mirror);
end
