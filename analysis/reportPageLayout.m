function L = reportPageLayout(sizes, opts)
%reportPageLayout  Where figure pages of given sizes go on one report sheet.
%   L = reportPageLayout(SIZES, PageSize=, Orientation=, MarginCm=, GapCm=)
%   arranges n pages (SIZES, n x 2: each page's width and height in cm, in
%   reading order) on one sheet of paper, in rows: the first row's pages
%   left to right, then the next row's. Every arrangement of c pages a row
%   (c = 1..n; the last row may hold fewer), on each orientation allowed,
%   is tried, and the one that draws the pages largest is kept. Every page
%   of a sheet is drawn at one scale, so the text of every page keeps the
%   same size relative to the others, and never larger than it was drawn
%   (scale <= 1). Pages of different sizes share rows: a row is as tall as
%   its tallest page and each page is centred in it; each row is centred
%   across the sheet, and the rows together are centred down it.
%
%   Arrangements within 2% of the largest scale count as equal: of those
%   the first orientation of the list (portrait, then landscape), then the
%   fewest rows, then the largest scale wins, so pages of similar sizes get
%   the same arrangement on every sheet.
%
%     PageSize     "letter" (21.59 x 27.94 cm, the default) | "a4" (21.0 x
%                  29.7 cm)
%     Orientation  "auto" (the default: portrait or landscape, whichever
%                  draws the pages larger) | "portrait" | "landscape"
%     MarginCm     the blank border around the sheet (default 1)
%     GapCm        the space between two pages, across and down (default
%                  0.5), not scaled
%
%   L is a struct:
%     sheetCm      [width height] of the sheet, cm
%     orientation  "portrait" | "landscape"
%     cols         pages a row (the last row may hold fewer)
%     rows         the number of rows
%     scale        the scale every page is drawn at (<= 1)
%     row          n x 1: each page's row (1 = top)
%     pos          n x 4: each page's place on the sheet, [x y width
%                  height] in cm from the sheet's lower-left corner (the
%                  PDF's origin), its scaled size
%     contentCm    [width height] of the sheet inside the margins
%
%   writePdfReport tiles the figure pages with it (Report.FiguresPerPage),
%   and writeHtmlReport sizes its tiles from it.
%
%   Errors: reportPageLayout:Sizes.
%
%   See also writePdfReport, writeHtmlReport.

arguments
    sizes (:,2) double
    opts.PageSize (1,1) string {mustBeMember(opts.PageSize, ["letter" "a4"])} = "letter"
    opts.Orientation (1,1) string {mustBeMember(opts.Orientation, ["auto" "portrait" "landscape"])} = "auto"
    opts.MarginCm (1,1) double {mustBeNonnegative} = 1
    opts.GapCm (1,1) double {mustBeNonnegative} = 0.5
end

n = size(sizes, 1);
if n == 0 || any(~isfinite(sizes(:))) || any(sizes(:) <= 0)
    error('reportPageLayout:Sizes', 'The pages'' sizes must be positive widths and heights, one row a page (got %s).', ...
        mat2str(sizes));
end
switch opts.PageSize
    case "a4", paper = [21.0 29.7];
    otherwise, paper = [21.59 27.94];
end
orients = ["portrait" "landscape"];
if opts.Orientation ~= "auto"; orients = opts.Orientation; end
m = opts.MarginCm;
g = opts.GapCm;

C = struct('o', {}, 'oi', {}, 'cols', {}, 'rows', {}, 'fit', {}, 'scale', {});
for oi = 1:numel(orients)
    S = paper;
    if orients(oi) == "landscape"; S = fliplr(paper); end
    W = S(1) - 2 * m;
    H = S(2) - 2 * m;
    for c = 1:n
        rows = ceil(n / c);
        if c > 1 && ceil(n / (c - 1)) == rows; continue; end   % the same rows with an emptier last one
        r = ceil((1:n).' / c);
        fit = Inf;
        for k = 1:rows
            in = r == k;
            fit = min(fit, (W - (nnz(in) - 1) * g) / sum(sizes(in, 1)));
        end
        rowH = accumarray(r, sizes(:, 2), [rows 1], @max);
        fit = min(fit, (H - (rows - 1) * g) / sum(rowH));
        if fit <= 0; continue; end   % the gaps alone fill the sheet
        C(end+1) = struct('o', orients(oi), 'oi', oi, 'cols', c, 'rows', rows, 'fit', fit, 'scale', min(fit, 1)); %#ok<AGROW>
    end
end
if isempty(C)
    error('reportPageLayout:Sizes', 'No arrangement of %d page(s) fits a %s sheet with margins of %g cm and gaps of %g cm.', ...
        n, opts.PageSize, m, g);
end
sc = [C.scale];
near = find(sc >= max(sc) * (1 - 0.02));
[~, best] = sortrows([[C(near).oi]; [C(near).rows]; -sc(near)].');
B = C(near(best(1)));

S = paper;
if B.o == "landscape"; S = fliplr(paper); end
s = B.scale;
r = ceil((1:n).' / B.cols);
rowH = accumarray(r, sizes(:, 2), [B.rows 1], @max) * s;
pos = zeros(n, 4);
W = S(1) - 2 * m;
H = S(2) - 2 * m;
top = S(2) - m - (H - sum(rowH) - (B.rows - 1) * g) / 2;   % the top of the current row
for k = 1:B.rows
    in = find(r == k);
    w = sizes(in, 1) * s;
    x = m + (W - sum(w) - (numel(in) - 1) * g) / 2;
    for q = 1:numel(in)
        h = sizes(in(q), 2) * s;
        pos(in(q), :) = [x, top - rowH(k) + (rowH(k) - h) / 2, w(q), h];
        x = x + w(q) + g;
    end
    top = top - rowH(k) - g;
end
L = struct('sheetCm', S, 'orientation', B.o, 'cols', B.cols, 'rows', B.rows, 'scale', s, ...
    'row', r, 'pos', pos, 'contentCm', S - 2 * m);
end
