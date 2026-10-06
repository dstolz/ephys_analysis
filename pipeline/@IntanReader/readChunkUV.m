function X = readChunkUV(obj, chunk)
%readChunkUV  Read one streaming chunk's amplifier data, in microvolts.
%   X = ds.readChunkUV(chunk) returns a [nSamp x nChan] double matrix of
%   amplifier data in MICROVOLTS for the chunk described by one element of
%   EphysDataset.streamPlan, dispatching on the on-disk layout. All amplifier
%   channels are returned in header order; the caller applies any channel
%   reorder/subset/exclusion (so the per-file channel-count guard in toBin still
%   sees the raw count). An empty result ([] or 0x0) means the chunk held no
%   amplifier data and should be skipped.
%
%   - "rhd"   chunks read the amplifier data of a whole traditional *.rhd
%             file (microvolts = 0.195*(uint16-32768)) straight from its data
%             blocks (recordingRows: the values READ_INTAN_RHD2000_FILE_MODIFIED
%             gives, without decoding the file's other signals). A file
%             saved before version 3.0 with the software notch on is
%             filtered as part of the recording's stream, from where the
%             file before it left off (to rounding), not from its own
%             first sample.
%   - "split" chunks read a sample window from the flat int16 .dat file(s) via
%             EphysDataset.readSplitWindow (microvolts = 0.195*int16).
%   Both produce microvolts on the same scale, so downstream processing is
%   format-agnostic.
%
%   See also EphysDataset.streamPlan, EphysDataset.readSplitWindow,
%   READ_INTAN_RHD2000_FILE_MODIFIED.

arguments
    obj (1,1) IntanReader
    chunk (1,1) struct
end

switch chunk.kind
    case "rhd"
        [~, stem, ext] = fileparts(chunk.file);
        name = string(stem) + string(ext);
        hdr = obj.rhdHeader(name);
        if hdr.numAmplifierChannels == 0 || hdr.numAmplifierSamples == 0
            X = zeros(0, 0);
            return
        end
        if isnan(chunk.sampleOffset)          % a file the header parse did not see: on its own
            X = obj.rhdRows(name, 1, hdr.numAmplifierSamples);
            if hdr.notchFrequency > 0 && hdr.mainVersion < 3
                X = IntanReader.notchFilter(X, hdr.sampleRate, hdr.notchFrequency);
            end
            return
        end
        X = obj.recordingRows(chunk.sampleOffset + 1, ...
            chunk.sampleOffset + hdr.numAmplifierSamples);   % [nSamp x nChan], microvolts

    case "split"
        X = obj.readSplitWindow(chunk.sampleOffset, chunk.nSamples);

    otherwise
        error('IntanReader:readChunkUV:BadKind', ...
            'Unknown chunk kind "%s".', chunk.kind);
end
end
