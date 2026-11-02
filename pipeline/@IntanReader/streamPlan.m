function plan = streamPlan(obj, opts)
%streamPlan  Format-agnostic list of streaming chunks for this recording.
%   PLAN = ds.streamPlan() returns a struct array describing the units in which
%   the recording should be read one-at-a-time, so the callers that stream the
%   data (toBin, analyzeArtifacts, the Visualize tab) can share a single loop
%   regardless of the on-disk layout. Each element is read with
%   EphysDataset.readChunkUV.
%
%   Every chunk is a bounded window, so peak memory does not grow with the
%   size of a file. For the traditional embedded-data format each *.rhd file
%   is cut into windows of at most MaxChunkSamples (a file that is smaller is
%   one chunk, as before; a window never crosses a file boundary); for the
%   split formats (one-file-per-signal / one-file-per-channel) the single big
%   amplifier .dat is carved into windows the same way. A leftover last
%   window shorter than one second joins the one before it
%   (EphysReader.planWindows), so no chunk is too short to filter.
%
%   Options
%   -------
%     Files            (1,:) string  subset/order of *.rhd files (traditional
%                      only; ignored for split formats, which have one data set).
%     MaxChunkSamples  (1,1) double  cap on samples per chunk (default:
%                      a memory-budget-derived size, ~250 MB of double).
%
%   Fields per element
%   ------------------
%     kind          "rhd" | "split"
%     name          display label (the file name, "<file> samples a-b" for a
%                   window of a file cut in several, or "samples a-b")
%     file          full path to the *.rhd file ("" for split chunks)
%     sampleOffset  0-based recording-global offset of the chunk's first
%                   sample: for rhd chunks the samples of the files before it
%                   in the recording (all files, chronological), whatever
%                   Files lists, plus the window's offset in its file; NaN
%                   for a file the header parse did not see
%     nSamples      amplifier samples in this chunk (NaN if header not parsed)
%
%   See also EphysDataset.readChunkUV, EphysDataset.toBin, EphysDataset.readSplitWindow.

arguments
    obj (1,1) IntanReader
    opts.Files (1,:) string = string.empty(1,0)
    opts.MaxChunkSamples (1,1) double = NaN
end

if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end

proto = struct('kind', "", 'name', "", 'file', "", ...
    'sampleOffset', 0, 'nSamples', 0);

switch obj.RecordingFormat
    case "traditional"
        if isempty(opts.Files)
            fileList = obj.Files;
        else
            fileList = opts.Files;
        end
        n = numel(fileList);
        maxc = opts.MaxChunkSamples;
        if isnan(maxc) || maxc <= 0
            % ~250 MB of double per chunk, but never less than ~1 s of data.
            maxc = max(round(obj.Fs), floor(2.5e8 / (max(obj.NumChannels, 1) * 8)));
        end
        maxc = max(1, maxc);
        pfNames = string.empty(1,0);
        starts = [];
        if ~isempty(obj.PerFile) && isfield(obj.PerFile, 'name')
            pfNames = string({obj.PerFile.name});
            starts = cumsum([0 obj.PerFile.numAmplifierSamples]);
        end
        parts = cell(1, n);
        for i = 1:n
            ns = NaN; s0 = NaN;
            j = find(pfNames == fileList(i), 1);
            if ~isempty(j); ns = obj.PerFile(j).numAmplifierSamples; s0 = starts(j); end
            if isnan(ns)                       % a file the header parse did not see: one chunk
                off = 0; len = NaN;
            else
                [off, len] = EphysReader.planWindows(ns, maxc, round(obj.Fs));
            end
            w = repmat(proto, 1, numel(off));
            for k = 1:numel(off)
                w(k).kind         = "rhd";
                w(k).name         = fileList(i);
                if numel(off) > 1
                    w(k).name     = sprintf('%s samples %d-%d', fileList(i), off(k) + 1, off(k) + len(k));
                end
                w(k).file         = fullfile(obj.Folder, fileList(i));
                w(k).sampleOffset = s0 + off(k);
                w(k).nSamples     = len(k);
            end
            parts{i} = w;
        end
        plan = [repmat(proto, 1, 0), parts{:}];

    case {"one-file-per-signal", "one-file-per-channel"}
        L = obj.splitLayout();
        total = L.nSamp;
        maxc = opts.MaxChunkSamples;
        if isnan(maxc) || maxc <= 0
            % ~250 MB of double per chunk, but never less than ~1 s of data.
            maxc = max(round(L.Fs), floor(2.5e8 / (max(L.nChan, 1) * 8)));
        end
        maxc = max(1, maxc);
        [off, len] = EphysReader.planWindows(total, maxc, round(L.Fs));
        plan = repmat(proto, 1, numel(off));
        for i = 1:numel(off)
            plan(i).kind         = "split";
            plan(i).name         = sprintf('samples %d-%d', off(i) + 1, off(i) + len(i));
            plan(i).file         = "";
            plan(i).sampleOffset = off(i);
            plan(i).nSamples     = len(i);
        end

    otherwise
        plan = repmat(proto, 1, 0);
end
end
