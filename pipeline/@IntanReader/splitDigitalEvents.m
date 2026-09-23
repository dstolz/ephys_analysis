function [events, names, native] = splitDigitalEvents(obj, nSamp)
%splitDigitalEvents  Digital-input events of a split-format recording.
%   [EVENTS, NAMES, NATIVE] = splitDigitalEvents(obj, NSAMP) decodes the
%   first NSAMP samples of the digital inputs - the digitalin.dat words
%   (one-file-per-signal) or each line's board-*.dat file (one-file-per-
%   channel, see splitLayout) - one window at a time as uint16, so memory
%   does not grow with the recording. EVENTS is keyed by the native line
%   names (matlab.lang.makeValidName) -> [k x 2] [t_on t_off] seconds,
%   t = row/Fs; samples past the end of a shorter digital file are low.
%   NAMES / NATIVE are the custom / native names of the lines read.
%
%   A line whose data file is missing is left out, with the warning
%   IntanReader:splitDigitalEvents:NoDigitalFile (all lines, when
%   digitalin.dat is missing).
%
%   See also IntanReader.readSplitAll, IntanReader.readDigitalEvents,
%   IntanReader.splitLayout.

L = obj.splitLayout();
events = struct();
names  = L.digInNames;
native = L.digInNative;
if isempty(native)
    return
end
step = 2^22;                                    % samples per window (8 MB of words)

switch L.format
    case "one-file-per-signal"
        if L.digInFile == "" || ~isfile(L.digInFile)
            warning('IntanReader:splitDigitalEvents:NoDigitalFile', ...
                '%s: info.rhd lists %d digital input(s) but digitalin.dat is missing; no digital events.', ...
                obj.Folder, numel(native));
            names  = string.empty(1, 0);
            native = string.empty(1, 0);
            return
        end
        parts = readWords(L.digInFile, nSamp, step, L.digInOrders);
    case "one-file-per-channel"
        have = L.digInFiles ~= "";
        if ~all(have)
            warning('IntanReader:splitDigitalEvents:NoDigitalFile', ...
                '%s: no data file for digital input(s) %s (looked for board-<native name>.dat and board-DIN-<nn>.dat); left out.', ...
                obj.Folder, strjoin(native(~have), ", "));
            names  = names(have);
            native = native(have);
        end
        files = L.digInFiles(have);
        parts = cell(numel(files), 1);
        for j = 1:numel(files)
            parts(j) = readWords(files(j), nSamp, step, []);
        end
end

keys = matlab.lang.makeValidName(cellstr(native));
for j = 1:numel(keys)
    events.(keys{j}) = EphysReader.joinRuns(parts{j}) ./ L.Fs;
end
end


function parts = readWords(file, nSamp, step, bits)
%readWords  Runs of the lines in a flat uint16 file, window by window.
%   PARTS{j} is a cell of the window runs of bit BITS(j) of each word, or,
%   with BITS empty, of the words themselves (> 0 is high; one line per file).
nLine = max(1, numel(bits));
parts = repmat({cell(1, 0)}, nLine, 1);
fid = fopen(char(file), 'r', 'ieee-le');
if fid < 0
    error('IntanReader:splitDigitalEvents:OpenFailed', 'Could not open %s', file);
end
closer = onCleanup(@() fclose(fid));
got = 0;
while got < nSamp
    w = fread(fid, min(step, nSamp - got), 'uint16=>uint16');
    if isempty(w); break; end
    for j = 1:nLine
        if isempty(bits)
            parts{j}{end+1} = EphysReader.highRuns(w, got);
        else
            parts{j}{end+1} = EphysReader.highRuns(EphysReader.wordBit(w, bits(j)), got);
        end
    end
    got = got + numel(w);
end
end
