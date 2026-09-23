function E = readDigitalEvents(obj, opts)
%readDigitalEvents  Digital-input events without reading the amplifier data.
%   E = r.readDigitalEvents() returns what EphysReader.readDigitalEvents
%   returns - events (keyed by the native line names, [k x 2] [t_on t_off]
%   seconds, t = row/Fs), Fs, nSamples, digInNames, digInNativeNames: the
%   events, rate, sample count and line names readData gives - but decodes
%   only the digital inputs, one bounded piece at a time, so memory does not
%   grow with the recording:
%     traditional   each file's data blocks are read in batches and only
%                   their digital-input words kept (sliceDataBlocks)
%     split         digitalin.dat, or each line's board-*.dat file, window
%                   by window (splitDigitalEvents)
%   ProgressFcn(i, nFiles, fileName) is called before each traditional file
%   (once, "info.rhd", for the split layouts).
%
%   Traditional recordings follow readData: the lines are the first file's
%   (later extra lines are ignored; a later file without a line has it low),
%   a file without amplifier data adds no samples, and a line high across a
%   file boundary gives one interval.
%
%   See also EphysReader.readDigitalEvents, EphysDataset.digitalEvents,
%   IntanReader.readData.

arguments
    obj (1,1) IntanReader
    opts.ProgressFcn = []
end

if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
if obj.NumFiles == 0
    error('IntanReader:readDigitalEvents:NoFiles', 'No Intan files in %s', obj.Folder);
end

if obj.RecordingFormat ~= "traditional"
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(1, 1, "info.rhd");
    end
    L = obj.splitLayout();
    n = L.nSamp;
    if L.format == "one-file-per-channel"
        for f = L.ampFiles                  % readSplitAll stops at the shortest file
            d = dir(f);
            n = min(n, floor(d.bytes / 2));
        end
    end
    [events, names, native] = obj.splitDigitalEvents(n);
    E = struct('events', events, 'Fs', L.Fs, 'nSamples', n, ...
        'digInNames', names, 'digInNativeNames', native);
    return
end

hdr1   = obj.rhdHeader(obj.Files(1));
names  = hdr1.digInNames;
native = hdr1.digInNativeNames;
nLine  = numel(native);
runs   = cell(nLine, obj.NumFiles);
n = 0;                                          % samples so far
for i = 1:obj.NumFiles
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(i, obj.NumFiles, obj.Files(i));
    end
    hdr = obj.rhdHeader(obj.Files(i));
    if hdr.numAmplifierChannels == 0 || hdr.numDataBlocks == 0
        continue                                % readData skips a file without amplifier data
    end
    runs(:, i) = fileRuns(obj, hdr, nLine, n);
    n = n + hdr.numAmplifierSamples;
end

events = struct();
if nLine > 0 && n > 0
    keys = matlab.lang.makeValidName(cellstr(native));
    for j = 1:nLine
        events.(keys{j}) = EphysReader.joinRuns(runs(j, :)) ./ hdr1.sampleRate;
    end
end
E = struct('events', events, 'Fs', hdr1.sampleRate, 'nSamples', n, ...
    'digInNames', names, 'digInNativeNames', native);
end


function R = fileRuns(obj, hdr, nLine, offset)
%fileRuns  Runs of the first NLINE digital inputs of one traditional file.
%   R{j}: [k x 2] rows (+ OFFSET) of line j, the file's own line j (its
%   native_order is the bit); a line the file does not have stays low.
R = repmat({zeros(0, 2)}, nLine, 1);
nHave = min(nLine, hdr.numBoardDigInChannels);
if nHave == 0
    return
end
ffn = fullfile(obj.Folder, hdr.name);
fid = fopen(ffn, 'r');
if fid < 0
    error('IntanReader:readDigitalEvents:OpenFailed', 'Could not open %s', ffn);
end
closer = onCleanup(@() fclose(fid));
if fseek(fid, hdr.headerBytes, 'bof') ~= 0
    error('IntanReader:readDigitalEvents:SeekFailed', 'Could not seek to the data of %s', ffn);
end
spb = hdr.numSamplesPerDataBlock;
per = max(1, floor(2^26 / hdr.bytesPerBlock));  % blocks per read: ~64 MB
parts = cell(nHave, ceil(hdr.numDataBlocks / per));
row = offset;
for k = 1:size(parts, 2)
    nb = min(per, hdr.numDataBlocks - (k - 1) * per);
    raw = fread(fid, [hdr.bytesPerBlock / 2, nb], 'uint16=>uint16');
    if size(raw, 2) < nb
        error('IntanReader:readDigitalEvents:ShortRead', ...
            '%s holds fewer data blocks than its header parse counted; refresh the metadata.', ffn);
    end
    S = IntanReader.sliceDataBlocks(raw, hdr, "digIn");
    for j = 1:nHave
        parts{j, k} = EphysReader.highRuns(EphysReader.wordBit(S.digIn, hdr.digInNativeOrders(j)), row);
    end
    row = row + nb * spb;
end
for j = 1:nHave
    R{j} = EphysReader.joinRuns(parts(j, :));
end
end
