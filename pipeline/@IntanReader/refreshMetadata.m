function refreshMetadata(obj)
%refreshMetadata  Fill header metadata for the recording (no data read).
%   For the traditional format this parses every *.rhd header; for the split
%   formats it parses info.rhd and sizes the recording from the .dat file(s) (see
%   refreshSplitMetadata / splitLayout). The traditional path below:
%   ds.refreshMetadata() parses the header of every file in ds.Files via
%   IntanReader.parseIntanHeader (header-only; no amplifier matrix is
%   allocated) and populates Fs, NumChannels, ChannelNames, NativeNames,
%   DigInNames, Duration, AcqDate, NumFiles and the PerFile struct array.
%   The parsed headers are kept for the window reads. AcqDate is the
%   recording start: the time in the first file's RHX name, else that
%   file's modification time (when RHX closed it) less its duration.
%
%   The recording's amplifier channels are every amplifier channel the
%   headers list, switched on or off in RHX, by native name, in the first
%   file's order (a channel only a later file lists comes after them). A
%   header lists the channels switched off too, so the channels keep their
%   places on the headstage, and the probe's sites theirs, whatever was
%   switched off. A channel a file does not hold (switched off from the
%   start, or off or on during the recording) reads as zeros there and is
%   listed in DroppedChannels (native, name, file, row: the file it changes
%   at, the first file when it is off throughout, and that file's first
%   recording row); EphysDataset leaves it out of every step
%   (excludedChannels), as a bad channel. A channel that changes during the
%   recording is warned about once (IntanReader:refreshMetadata:ChannelsDropped,
%   naming the channels and the files they change at). Each file's columns
%   for the recording's channels are kept for the reads (fileColumns). A
%   file whose sample rate differs is refused
%   (IntanReader:refreshMetadata:RateMismatch).
%   Dig-in channel counts follow the first-file policy used by intan2matlab
%   (later extra lines ignored).
%
%   The acquisition clock is checked too (IntanReader.scanTimestamps): each
%   file's first timestamp and the one it should be followed by are kept in
%   PerFile (firstTimestamp, endTimestamp), a file that does not start where
%   the one before it ended gives PerFile.gapBefore (samples; 0 when it
%   does, NaN for the first), and jumps between the data blocks of a file
%   give PerFile.numGaps. Every jump also warns IntanReader:TimestampGap
%   and is listed in the reader's Gaps (file, row, samples): the rows
%   are read as contiguous whatever the clock did, so a pause shows in no
%   other time. A split recording's time.dat is checked the same way.
%
%   See also IntanReader.parseIntanHeader, EphysDataset.readData.

arguments
    obj (1,1) IntanReader
end

obj.discoverFiles();  % re-scan in case files changed on disk

% Split formats (info.rhd + flat .dat files): the header carries no data
% blocks, so amplifier sample counts come from the .dat file size(s) resolved by
% splitLayout, not from parseIntanHeader's block count.
if obj.RecordingFormat == "one-file-per-signal" || ...
        obj.RecordingFormat == "one-file-per-channel"
    refreshSplitMetadata(obj);
    return
end

if obj.NumFiles == 0
    warning('IntanReader:refreshMetadata:NoFiles', ...
        'No *.rhd files found in %s', obj.Folder);
    return
end

pf = struct('name', {}, 'bytesPerBlock', {}, 'numDataBlocks', {}, ...
    'numAmplifierSamples', {}, 'recordTime', {}, 'numAmplifierChannels', {}, ...
    'numBoardDigIn', {}, 'headerBytes', {}, 'datenum', {}, 'partialBlock', {}, ...
    'dataPresent', {}, 'firstTimestamp', {}, 'endTimestamp', {}, 'numGaps', {}, 'gapBefore', {});
gaps = emptyGaps();

% Every header first: the recording's channels are those the headers list.
hdrs = cell(1, obj.NumFiles);
for i = 1:obj.NumFiles
    hdrs{i} = obj.rhdHeader(obj.Files(i));
end
hdrs = [hdrs{:}];
[native, custom, dropped, cols, changed] = channelSet(hdrs);
obj.Fs           = hdrs(1).sampleRate;
obj.NumChannels  = numel(native);
obj.ChannelNames = custom;
obj.NativeNames  = native;
obj.ChannelNumbers = IntanReader.channelNumbersFor(obj.NativeNames, obj.Folder);
obj.DigInNames   = hdrs(1).digInNames;
obj.DigInNativeNames = hdrs(1).digInNativeNames;
obj.DroppedChannels = dropped;
obj.pColumns = struct('name', num2cell([hdrs.name]), 'columns', cols);
if any(changed)
    warnDropped(obj.Folder, dropped(changed), obj.Fs);
end

prevEnd = NaN;                                  % the clock where the last file with data ended
prevName = "";
rowsBefore = 0;                                 % rows of the files before this one
for i = 1:obj.NumFiles
    hdr = hdrs(i);

    if hdr.sampleRate ~= obj.Fs
        error('IntanReader:refreshMetadata:RateMismatch', ...
            ['Sample rate changed mid-dataset (%g -> %g Hz) at %s. One clock cannot ', ...
             'cover the recording; split it at that file.'], obj.Fs, hdr.sampleRate, obj.Files(i));
    end

    if hdr.partialBlock
        warning('IntanReader:refreshMetadata:PartialBlock', ...
            'Truncated trailing data block in %s; only whole blocks counted.', obj.Files(i));
    end

    % The acquisition clock: where the file starts, and every jump in it.
    ts = IntanReader.scanTimestamps(fullfile(obj.Folder, hdr.name), hdr.headerBytes, ...
        hdr.bytesPerBlock, hdr.numDataBlocks, hdr.numSamplesPerDataBlock, ...
        hdr.mainVersion == 1 && hdr.secondaryVersion < 2);
    gapBefore = NaN;
    if hdr.numDataBlocks > 0
        if ~isnan(prevEnd)
            gapBefore = wrapSamples(ts.first - prevEnd);
            if gapBefore ~= 0
                gaps(end+1) = struct('file', string(hdr.name), 'row', rowsBefore + 1, 'samples', gapBefore); %#ok<AGROW>
                warnBoundary(obj.Folder, hdr.name, prevName, gapBefore, hdr.sampleRate);
            end
        end
        if ~isempty(ts.index)
            rows = rowsBefore + ts.index * hdr.numSamplesPerDataBlock + 1;
            gaps = [gaps, struct('file', repmat({string(hdr.name)}, 1, numel(rows)), ...
                'row', num2cell(rows.'), 'samples', num2cell(ts.jumps.'))]; %#ok<AGROW>
            warnInFile(hdr.name, rows, ts.jumps, hdr.sampleRate);
        end
        prevEnd = ts.end;
        prevName = hdr.name;
    end
    rowsBefore = rowsBefore + hdr.numAmplifierSamples;

    pf(i) = struct('name', hdr.name, 'bytesPerBlock', hdr.bytesPerBlock, ...
        'numDataBlocks', hdr.numDataBlocks, ...
        'numAmplifierSamples', hdr.numAmplifierSamples, ...
        'recordTime', hdr.recordTime, ...
        'numAmplifierChannels', hdr.numAmplifierChannels, ...
        'numBoardDigIn', hdr.numBoardDigInChannels, ...
        'headerBytes', hdr.headerBytes, 'datenum', hdr.datenum, ...
        'partialBlock', hdr.partialBlock, 'dataPresent', hdr.dataPresent, ...
        'firstTimestamp', ts.first, 'endTimestamp', ts.end, ...
        'numGaps', numel(ts.index), 'gapBefore', gapBefore);
end

obj.PerFile  = pf;
obj.Gaps     = gaps;
obj.pNotch   = [];
obj.fileNotch();                                % kept for the window reads
obj.Duration = sum([pf.recordTime]);
obj.AcqDate  = obj.startTime();

end


% =========================================================================
function refreshSplitMetadata(obj)
%refreshSplitMetadata  Fill metadata for a split-format recording.
%   Parses info.rhd for header fields and derives the amplifier sample count
%   from the .dat file size(s) (the header has no data blocks). Mirrors the
%   PerFile summary the traditional path builds, with a single entry standing in
%   for the whole recording, so downstream code (NumSamples, the GUI tables,
%   onPlotVisualization) is unchanged. AcqDate is the recording start: the
%   time in the folder's RHX name, else amplifier.dat's modification time
%   (the end of the recording) less its duration.
L = obj.splitLayout();

obj.Fs           = L.Fs;
obj.NumChannels  = L.nChan;
obj.ChannelNames = L.ampCustom;
obj.NativeNames  = L.ampNative;
obj.ChannelNumbers = IntanReader.channelNumbersFor(L.ampNative, obj.Folder);
obj.DigInNames   = L.digInNames;
obj.DigInNativeNames = L.digInNative;
off = setdiff(1:L.nChan, L.ampOn);              % one header: off throughout, or on throughout
obj.DroppedChannels = struct('native', num2cell(L.ampNative(off)), 'name', num2cell(L.ampCustom(off)), ...
    'file', "info.rhd", 'row', 1);
if isempty(off); obj.DroppedChannels = emptyDropped(); end

nSamp = L.nSamp;
ts = struct('first', NaN, 'end', NaN, 'index', zeros(0, 1), 'jumps', zeros(0, 1));
gaps = emptyGaps();
if isfile(L.timeFile)
    d = dir(char(L.timeFile));
    nTime = min(nSamp, floor(d.bytes / 4));      % the stamps there are, for the samples there are
    ts = IntanReader.scanTimestamps(L.timeFile, 0, 4, nTime, 1);
    if ~isempty(ts.index)
        gaps = struct('file', repmat({"time.dat"}, 1, numel(ts.index)), ...
            'row', num2cell(ts.index.' + 1), 'samples', num2cell(ts.jumps.'));
        warnInFile("time.dat", ts.index + 1, ts.jumps, L.Fs);
    end
end
obj.Gaps = gaps;
obj.PerFile = struct( ...
    'name',                 "info.rhd", ...
    'bytesPerBlock',        NaN, ...
    'numDataBlocks',        NaN, ...
    'numAmplifierSamples',  nSamp, ...
    'recordTime',           nSamp / L.Fs, ...
    'numAmplifierChannels', numel(L.ampOn), ...
    'numBoardDigIn',        numel(L.digInNames), ...
    'headerBytes',          NaN, ...
    'datenum',              L.ampDatenum, ...
    'partialBlock',         false, ...
    'dataPresent',          nSamp > 0, ...
    'firstTimestamp',       ts.first, ...
    'endTimestamp',         ts.end, ...
    'numGaps',              numel(ts.index), ...
    'gapBefore',            NaN);

obj.Duration = nSamp / L.Fs;
obj.AcqDate  = obj.startTime();

end


% =========================================================================
function [native, custom, dropped, cols, changed] = channelSet(hdrs)
%channelSet  The recording's amplifier channels: every one the headers list.
%   HDRS are the parsed headers of the recording's files, in order. NATIVE
%   and CUSTOM name the amplifier channels the headers list, switched on or
%   off (listedNativeNames, listedChannelNames): those of the first file
%   that lists any, in its order, then those only a later file lists, in
%   the order they come. DROPPED (the EphysReader.DroppedChannels fields:
%   native, name, file, row) lists those a file with amplifier channels does
%   not hold, in the order of FILE, then the channel's place: FILE is where
%   the channel changes (the first file that lacks it when the first file
%   with amplifier channels holds it, else the first that holds it), or
%   that first file when no file holds it; ROW is that file's first
%   recording row. CHANGED marks the elements of DROPPED some file holds
%   (switched off or on during the recording). COLS{k} is fileColumns'
%   answer for file k: for each channel, the row of its amplifier matrix
%   holding it (0 where the file does not), [] when it holds exactly the
%   channels in order (or has none).
nFiles = numel(hdrs);
native = string.empty(1, 0);
custom = string.empty(1, 0);
for k = 1:nFiles
    ln = reshape(string(hdrs(k).listedNativeNames), 1, []);
    lc = reshape(string(hdrs(k).listedChannelNames), 1, []);
    new = ~ismember(ln, native);
    native = [native, ln(new)]; %#ok<AGROW>
    custom = [custom, lc(new)]; %#ok<AGROW>
end
withAmp = find([hdrs.numAmplifierChannels] > 0);
on = false(numel(native), nFiles);                 % on(j, k): file k holds channel j
for k = withAmp
    on(:, k) = ismember(native, string(hdrs(k).nativeNames)).';
end
starts = cumsum([0 hdrs.numAmplifierSamples]);   % the recording row before each file
dropped = emptyDropped();
changed = false(1, 0);
at = zeros(1, 0);                                 % the file each changes at, for the order
for j = find(~all(on(:, withAmp), 2)).'
    held = on(j, withAmp);
    f = withAmp(1);                               % off throughout: from the first file
    if held(1)
        f = withAmp(find(~held, 1));              % switched off
    elseif any(held)
        f = withAmp(find(held, 1));               % switched on
    end
    dropped(end+1) = struct('native', native(j), 'name', custom(j), ...
        'file', string(hdrs(f).name), 'row', starts(f) + 1); %#ok<AGROW>
    changed(end+1) = any(held); %#ok<AGROW>
    at(end+1) = f; %#ok<AGROW>
end
[~, order] = sort(at);                            % stable: then the channel's place
dropped = dropped(order);
changed = changed(order);
cols = cell(1, nFiles);
for k = withAmp
    cols{k} = IntanReader.channelColumns(hdrs(k).nativeNames, native);
end
end


function warnDropped(folder, dropped, Fs)
%warnDropped  One warning naming the channels switched off or on during the recording and the files they change at.
parts = strings(1, 0);
for f = unique([dropped.file], 'stable')
    d = dropped([dropped.file] == f);
    parts(end+1) = sprintf('%s at %s (row %d, %.1f s in)', ...
        strjoin([d.native], ', '), f, d(1).row, (d(1).row - 1) / Fs); %#ok<AGROW>
end
warning('IntanReader:refreshMetadata:ChannelsDropped', ...
    ['%s: %d amplifier channel(s) switched off or on during the recording: %s. Each keeps its place, ' ...
     'with zeros where a file does not hold it, and is left out of every step, as a bad channel ' ...
     '(DroppedChannels).'], folder, numel(dropped), strjoin(parts, '; '));
end


function d = emptyDropped()
%emptyDropped  A DroppedChannels list with no element (the EphysReader.DroppedChannels fields).
d = struct('native', {}, 'name', {}, 'file', {}, 'row', {});
end


function g = emptyGaps()
%emptyGaps  A Gaps list with no element (the EphysReader.Gaps fields).
g = struct('file', {}, 'row', {}, 'samples', {});
end


function d = wrapSamples(d)
%wrapSamples  A difference of two 32-bit stamps as a signed number of samples.
d = mod(d + 2^31, 2^32) - 2^31;
end


function warnBoundary(folder, name, prevName, gap, Fs)
%warnBoundary  A file that does not start where the one before it ended.
if gap > 0
    how = sprintf('%d samples (%.3g s) after', gap, gap / Fs);
    effect = 'early';
else
    how = sprintf('%d samples (%.3g s) before', -gap, -gap / Fs);
    effect = 'late';
end
warning('IntanReader:TimestampGap', ...
    ['%s: %s starts %s %s ended on the acquisition clock (a pause, dropped samples, ' ...
     'or files that do not belong together). The rows are read as contiguous, so the ' ...
     'times from this file on are %s by that much against the wall clock.'], ...
    folder, name, how, prevName, effect);
end


function warnInFile(name, rows, jumps, Fs)
%warnInFile  Jumps of the acquisition clock between the blocks of one file.
missing = sum(jumps);
warning('IntanReader:TimestampGap', ...
    ['%s: the acquisition clock jumps at %d place(s) (first at row %d of the file, by %d samples; ' ...
     '%d samples, %.3g s, in all). The rows are read as contiguous, so the times after ' ...
     'a jump are off by the samples missing against the wall clock.'], ...
    name, numel(rows), rows(1), jumps(1), missing, missing / Fs);
end
