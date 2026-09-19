function [T, row, kept] = stitchCopySessions(T, rows)
%stitchCopySessions  Merge source session rows into one recording whose ePsych files are stitched.
%   T = stitchCopySessions(T, rows) takes a findCopySessions table and the
%   rows (indices or a logical mask), picked by hand, that hold one
%   recording folder and the ePsych files that belong to it, and replaces
%   them with one "stitched" row. copySessions copies that row's recording
%   folder and joins its ePsych files, in chronological order, into one
%   Epsych2 session file (stitchEpsychSessions), so the local session folder
%   holds a single behavior file as usual.
%
%   The rows must hold exactly one recording folder and, between them, at least
%   two ePsych files, all of one subject. Rows of any status can be merged:
%   ambiguous rows (picking the files resolves them) and rows stitched
%   before (their files join the new set).
%
%   The stitched row takes the recording folder row's place (RecordingDir,
%   RecordingTime, RecordingDuration, Reader, DestDir are kept); the other
%   rows are removed. It has
%     Status        "stitched"
%     StitchFiles   every ePsych file, in chronological order (by the time in
%                   its name, as findCopySessions reads it)
%     EpsychFile, EpsychTime, DeltaT   those of the earliest file
%     EpsychTrials  the sum over the files (NaN when a count is unknown)
%     Note          the files in order, each with its start relative to the
%                   recording
%
%   [T, ROW, KEPT] = stitchCopySessions(...) also returns the stitched row's
%   index in the returned T and a logical mask of the input rows that remain
%   (in order), to carry per-row state such as tick boxes along.
%
%   Errors with stitchCopySessions:BadRows when ROWS name fewer than two
%   rows, several subjects, not exactly one recording folder, fewer than two
%   ePsych files, or an ePsych file whose name holds no time.
%
%   Example
%     T = findCopySessions("SUBJ-ID-1255", "260916");
%     T = stitchCopySessions(T, [2 3]);      % a recording and a second ePsych file
%     R = copySessions(T, DryRun=false);
%
%   See also findCopySessions, copySessions, stitchEpsychSessions.

arguments
    T table
    rows {mustBeVector}
end

if islogical(rows)
    rows = find(rows);
end
rows = unique(double(rows(:)));
if numel(rows) < 2 || any(rows < 1 | rows > height(T) | rows ~= round(rows))
    error('stitchCopySessions:BadRows', 'Pick at least two rows of the session table to stitch.');
end
S = T(rows, :);
subjects = unique(S.Subject);
if numel(subjects) > 1
    error('stitchCopySessions:BadRows', 'The rows belong to different subjects: %s.', strjoin(subjects, ", "));
end
row = rows(S.RecordingDir ~= "");
if numel(row) ~= 1
    error('stitchCopySessions:BadRows', 'The rows must hold exactly one recording folder; they hold %d.', numel(row));
end

files = [S.EpsychFile; vertcat(S.StitchFiles{:})];
files = unique(files(files ~= ""));
if numel(files) < 2
    error('stitchCopySessions:BadRows', 'The rows must hold at least two ePsych files to stitch; they hold %d.', numel(files));
end
times = NaT(numel(files), 1);
for k = 1:numel(files)
    tok = regexp(files(k), '_(\d{6})T(\d{6})\.mat$', 'tokens', 'once');
    if ~isempty(tok)
        try
            times(k) = datetime(tok(1) + tok(2), 'InputFormat', 'yyMMddHHmmss');
        catch
            % an impossible date or time: NaT, reported below
        end
    end
    if isnat(times(k))
        error('stitchCopySessions:BadRows', 'The time of %s cannot be read from its name.', files(k));
    end
end
[times, order] = sort(times);
files = files(order);

delta = times - T.RecordingTime(row);
parts = strings(numel(files), 1);
for k = 1:numel(files)
    [~, n, x] = fileparts(files(k));
    parts(k) = sprintf("%s (%+.0f s)", n + x, seconds(delta(k)));
end

T.Status(row) = "stitched";
T.EpsychFile(row) = files(1);
T.EpsychTime(row) = times(1);
T.DeltaT(row) = delta(1);
T.EpsychTrials(row) = sum(S.EpsychTrials(S.EpsychFile ~= ""));
T.StitchFiles{row} = files;
T.Note(row) = "stitched by hand, in chronological order: " + strjoin(parts, "; ");

kept = true(height(T), 1);
kept(rows(rows ~= row)) = false;
T = T(kept, :);
row = nnz(kept(1:row));
end
