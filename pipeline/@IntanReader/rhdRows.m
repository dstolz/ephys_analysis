function X = rhdRows(obj, name, lo, hi)
%rhdRows  Rows LO..HI of one traditional *.rhd file's amplifier data, in microvolts.
%   X = rhdRows(obj, NAME, LO, HI) returns [HI-LO+1 x nChan] double
%   microvolts (0.195 * (code - 32768)), every amplifier channel in header
%   order, for the 1-based rows LO..HI of the file NAME in obj.Folder. Only
%   the data blocks holding those rows are read (one fseek, one fread), and
%   they are split by sliceDataBlocks as READ_INTAN_RHD2000_FILE_MODIFIED
%   splits a whole file, so the rows equal those of a whole-file read.
%
%   The exception is a file saved before version 3.0 with the software notch
%   filter on: READ_INTAN_RHD2000_FILE_MODIFIED filters it from the file's
%   first sample, so such a file is read whole and the rows taken from it.
%
%   See also IntanReader.readWindowUV, IntanReader.readChunkUV,
%   IntanReader.sliceDataBlocks.

hdr = obj.rhdHeader(name);
ffn = fullfile(obj.Folder, name);
if hi < lo
    X = zeros(0, hdr.numAmplifierChannels);
    return
end
if lo < 1 || hi > hdr.numAmplifierSamples
    error('IntanReader:rhdRows:OutOfRange', ...
        'Rows %d-%d asked of %s, which holds %d.', lo, hi, name, hdr.numAmplifierSamples);
end
if hdr.notchFrequency > 0 && hdr.mainVersion < 3
    S = read_Intan_RHD2000_file_modified(ffn, Verbosity="silent");
    X = S.amplifier_data(:, lo:hi).';
    return
end

spb = hdr.numSamplesPerDataBlock;
b0 = floor((lo - 1) / spb);                       % first block read (0-based)
nb = floor((hi - 1) / spb) - b0 + 1;
fid = fopen(ffn, 'r');
if fid < 0
    error('IntanReader:rhdRows:OpenFailed', 'Could not open %s', ffn);
end
closer = onCleanup(@() fclose(fid));
if fseek(fid, hdr.headerBytes + b0 * hdr.bytesPerBlock, 'bof') ~= 0
    error('IntanReader:rhdRows:SeekFailed', 'Could not seek to data block %d of %s', b0 + 1, ffn);
end
raw = fread(fid, [hdr.bytesPerBlock / 2, nb], 'uint16=>uint16');
clear closer
if size(raw, 2) < nb
    error('IntanReader:rhdRows:ShortRead', ...
        '%s holds fewer data blocks than its header parse counted; refresh the metadata.', ffn);
end
S = IntanReader.sliceDataBlocks(raw, hdr, "amplifier");
clear raw
X = double(S.amplifier(:, lo - b0 * spb : hi - b0 * spb).');
X = 0.195 * (X - 32768);
end
