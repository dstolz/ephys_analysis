function [lines, pos] = readNewLines(file, pos)
%readNewLines  The whole lines a growing text file has gained since byte POS.
%   [LINES, POS] = readNewLines(FILE, POS) reads FILE from byte offset POS
%   and returns its complete (newline-terminated) lines as a string column,
%   with the offset just after the last of them, so the next call resumes
%   there. A partial last line waits for the next call. Each line is
%   reduced to what a terminal shows: the CR of a CRLF ending is dropped
%   (Python on Windows writes CRLF to a redirected stdout), and a line that
%   carriage returns overwrite (tqdm progress bars) is reduced to its
%   final state. Blank lines are left out. A file that is missing or
%   cannot be read gives no lines and POS unchanged.
%
%   The preprocessing app streams each background Kilosort4 run's
%   ks4_run.log into its status box with it (pollKSRuns).
%
%   See also EphysDataset.sortRunState.

arguments
    file (1,1) string
    pos (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end
lines = strings(0, 1);
if file == "" || ~isfile(file); return; end
fid = fopen(file, 'r');   % binary: ftell == byte offset
if fid < 0; return; end
try
    fseek(fid, pos, 'bof');
    chunk = fread(fid, inf, '*char').';
catch
    fclose(fid);
    return
end
fclose(fid);
nl = find(chunk == newline, 1, 'last');
if isempty(nl); return; end
pos = pos + nl;
parts = split(string(chunk(1:nl)), newline);
parts(end) = [];   % the empty segment after the last newline
for k = 1:numel(parts)
    s = regexprep(parts(k), '\r+$', '');
    seg = split(s, sprintf('\r'));
    s = seg(end);
    if strlength(strip(s)) > 0
        lines(end+1, 1) = s; %#ok<AGROW>
    end
end
end
