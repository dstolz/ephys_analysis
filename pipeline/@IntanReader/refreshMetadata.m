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
%   The recording's amplifier channels are those any file (with amplifier
%   channels) holds, by native name, in the files' order. RHX lets a
%   channel be switched off, or on, while it records, and the files from
%   then on lack it, or hold it: such a channel stays in the recording, so
%   its rows and the probe map's rows still line up, reads as zero in the
%   files that lack it, is warned about once
%   (IntanReader:refreshMetadata:ChannelsDropped, naming the channels and
%   the files they change at) and is listed in DroppedChannels (native,
%   name, file, row: the first file that differs on it and that file's
%   first recording row). EphysDataset.excludedChannels then leaves it out
%   of every step as a bad channel. Each file's columns for the recording's
%   channels are kept for the reads (fileColumns). A file whose sample rate
%   differs is refused (IntanReader:refreshMetadata:RateMismatch).
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

% Every header first: the recording's channels are those any file holds.
hdrs = cell(1, obj.NumFiles);
for i = 1:obj.NumFiles
    hdrs{i} = obj.rhdHeader(obj.Files(i));
end
hdrs = [hdrs{:}];
[native, custom, dropped, cols] = channelSet(hdrs);
obj.Fs           = hdrs(1).sampleRate;
obj.NumChannels  = numel(native);
obj.ChannelNames = custom;
obj.NativeNames  = native;
obj.ChannelNumbers = IntanReader.channelNumbersFor(obj.NativeNames, obj.Folder);
obj.DigInNames   = hdrs(1).digInNames;
obj.DigInNativeNames = hdrs(1).digInNativeNames;
obj.DroppedChannels = dropped;
obj.pColumns = struct('name', num2cell([hdrs.name]), 'columns', cols);
if ~isempty(dropped)
    warnDropped(obj.Folder, dropped, obj.NumChannels, obj.Fs);
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
obj.DroppedChannels = emptyDropped();           % one header: the channels cannot differ

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
    'numAmplifierChannels', L.nChan, ...
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
function [native, custom, dropped, cols] = channelSet(hdrs)
%channelSet  The recording's amplifier channels: those any file holds.
%   HDRS are the parsed headers of the recording's files, in order. NATIVE
%   and CUSTOM are the native and custom names of every amplifier channel a
%   file holds, in the files' order: the first file's channels, and each
%   channel a later file adds after the channel that file holds before it
%   (RHX writes the enabled channels in hardware order, so the recording
%   keeps that order and the rows a probe map was written for). DROPPED
%   lists the channels the files do not all hold (the
%   EphysReader.DroppedChannels fields: native, name, file, row), in the
%   order of the file they change at, then the recording's order: a channel
%   of the first file that a later file lacks (file: the first that lacks
%   it) and a channel the first file lacks (file: the first that holds it);
%   row is that file's first recording row. COLS{k} is fileColumns' answer
%   for file k: the rows of its amplifier matrix holding the recording's
%   channels in order, 0 for a channel it lacks, [] when they are exactly
%   its channels (or it has none).
nFiles = numel(hdrs);
withAmp = find([hdrs.numAmplifierChannels] > 0);
native = strings(1, 0);
custom = strings(1, 0);
for k = withAmp
    names = reshape(string(hdrs(k).nativeNames), 1, []);
    cnames = reshape(string(hdrs(k).channelNames), 1, []);
    at = 0;                                         % the place the next new channel goes after
    for j = 1:numel(names)
        p = find(native == names(j), 1);
        if isempty(p)
            native = [native(1:at), names(j), native(at+1:end)]; %#ok<AGROW>
            custom = [custom(1:at), cnames(j), custom(at+1:end)]; %#ok<AGROW>
            at = at + 1;
        else
            at = p;
        end
    end
end
starts = cumsum([0 hdrs.numAmplifierSamples]);   % the recording row before each file
dropped = emptyDropped();
if ~isempty(withAmp)
    held0 = ismember(native, string(hdrs(withAmp(1)).nativeNames));
    seen = false(size(native));
    for k = withAmp(2:end)
        heldK = ismember(native, string(hdrs(k).nativeNames));
        for j = find(heldK ~= held0 & ~seen)
            dropped(end+1) = struct('native', native(j), 'name', custom(j), ...
                'file', string(hdrs(k).name), 'row', starts(k) + 1); %#ok<AGROW>
        end
        seen = seen | heldK ~= held0;
    end
end
cols = cell(1, nFiles);
for k = withAmp
    cols{k} = IntanReader.channelColumns(hdrs(k).nativeNames, native);
end
end


function warnDropped(folder, dropped, nChan, Fs)
%warnDropped  One warning naming the channels that change and the files they change at.
parts = strings(1, 0);
for f = unique([dropped.file], 'stable')
    d = dropped([dropped.file] == f);
    parts(end+1) = sprintf('%s from %s (row %d, %.1f s in)', ...
        strjoin([d.native], ', '), f, d(1).row, (d(1).row - 1) / Fs); %#ok<AGROW>
end
warning('IntanReader:refreshMetadata:ChannelsDropped', ...
    ['%s: the amplifier channels change during the recording: %s. The recording keeps all %d ' ...
     'channels, so the probe map still fits; the %d that change read as zero where a file lacks them ' ...
     'and are left out of every step as bad channels (DroppedChannels). ' ...
     'To use the rows a channel recorded, split the recording at the file it changes in.'], ...
    folder, strjoin(parts, '; '), nChan, numel(dropped));
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
