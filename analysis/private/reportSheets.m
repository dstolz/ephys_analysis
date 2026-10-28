function sheets = reportSheets(counts, perSheet)
%reportSheets  Which pages share a sheet, for Report.FiguresPerPage.
%   SHEETS = reportSheets(COUNTS, N) splits pages that come in blocks (a
%   figure's pages, or an observation's: COUNTS(b) pages in block b, the
%   blocks in order) into sheets of at most N pages, keeping each block
%   whole where it can: pages fill a sheet in order, and a block that does
%   not fit in what is left of the current sheet starts the next one. A
%   block of more than N pages starts a sheet of its own and is spread as
%   evenly as it goes over as few sheets as hold it (7 pages, 4 a sheet:
%   4 and 3; 5: 3 and 2), the next block starting a fresh sheet. SHEETS
%   is a cell row, each a row of indices into the pages counted in order
%   (1..sum(COUNTS)). N = 1 is a sheet a page.
%
%   See also reportPageLayout, writePdfReport, writeHtmlReport.

sheets = cell(1, 0);
cur = zeros(1, 0);
at = 0;
for b = 1:numel(counts)
    n = counts(b);
    if n == 0; continue; end
    idx = at + (1:n);
    at = at + n;
    if n <= perSheet
        if numel(cur) + n > perSheet
            sheets{end+1} = cur; %#ok<AGROW>
            cur = zeros(1, 0);
        end
        cur = [cur idx]; %#ok<AGROW>
        continue
    end
    if ~isempty(cur)
        sheets{end+1} = cur; %#ok<AGROW>
        cur = zeros(1, 0);
    end
    k = ceil(n / perSheet);
    sz = floor(n / k) + ((1:k) <= mod(n, k));   % the larger sheets first
    edges = [0 cumsum(sz)];
    for j = 1:k
        sheets{end+1} = idx(edges(j) + 1:edges(j + 1)); %#ok<AGROW>
    end
end
if ~isempty(cur); sheets{end+1} = cur; end
end
