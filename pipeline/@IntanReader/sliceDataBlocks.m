function S = sliceDataBlocks(raw, hdr, signals)
%sliceDataBlocks  Split whole data blocks of a traditional *.rhd file into signals.
%   S = IntanReader.sliceDataBlocks(RAW, HDR) takes RAW, whole data blocks
%   read as uint16 words, one block per column ([bytesPerBlock/2 x nBlocks],
%   e.g. fread(fid, [HDR.bytesPerBlock/2, nBlocks], 'uint16=>uint16') from
%   the start of a block), and returns each signal's codes as stored, with
%   channels down the rows and samples along (Intan's orientation);
%   n = nBlocks * spb samples:
%     timestamps  [1 x n] double (int32; uint32 before file version 1.2)
%     amplifier   [nAmp x n] uint16       microvolts = 0.195 * (code - 32768)
%     aux         [nAux x n/4] uint16     volts = 37.4e-6 * code
%     supply      [nSupply x nBlocks] uint16
%     temp        [nTemp x nBlocks] int16
%     adc         [nADC x n] uint16
%     digIn       [1 x n] uint16 words    bit k = the line whose native_order is k
%     digOut      [1 x n] uint16 words
%   A signal the file does not hold comes back with no rows (digIn / digOut:
%   1 x 0). S = IntanReader.sliceDataBlocks(RAW, HDR, SIGNALS) slices only
%   the signals named in the string array SIGNALS.
%
%   HDR gives the block layout in parseIntanHeader's fields:
%   numSamplesPerDataBlock (spb), numAmplifierChannels, numAuxInputChannels,
%   numSupplyVoltageChannels, numTempSensorChannels, numBoardADCChannels,
%   numBoardDigInChannels, numBoardDigOutChannels, mainVersion and
%   secondaryVersion. A block holds, in this order: one 32-bit timestamp
%   per sample; the amplifier samples channel by channel (spb each); the aux
%   samples channel by channel (spb/4 each); one supply-voltage word and one
%   temperature word per channel; the ADC samples channel by channel; spb
%   digital-input words (when the file has input lines) and spb
%   digital-output words (when it has output lines).
%
%   READ_INTAN_RHD2000_FILE_MODIFIED reads whole files through this; the
%   window reads (readWindowUV, readChunkUV) and readDigitalEvents slice the
%   blocks they read with it too, so every path decodes the blocks alike.
%
%   See also IntanReader.parseIntanHeader, READ_INTAN_RHD2000_FILE_MODIFIED.

arguments
    raw uint16
    hdr (1,1) struct
    signals (1,:) string = ["timestamps" "amplifier" "aux" "supply" "temp" "adc" "digIn" "digOut"]
end

spb = hdr.numSamplesPerDataBlock;
words = [2 * spb, ...                                   % timestamps (2 words each)
         spb * hdr.numAmplifierChannels, ...
         spb / 4 * hdr.numAuxInputChannels, ...
         hdr.numSupplyVoltageChannels, ...
         hdr.numTempSensorChannels, ...
         spb * hdr.numBoardADCChannels, ...
         spb * (hdr.numBoardDigInChannels > 0), ...
         spb * (hdr.numBoardDigOutChannels > 0)];
first = cumsum([0 words(1:end-1)]);                     % words before each signal in a block
if isempty(raw)
    raw = zeros(sum(words), 0, 'uint16');
end
if size(raw, 1) ~= sum(words)
    error('IntanReader:sliceDataBlocks:BlockSize', ...
        'Blocks of %d words given; the header describes %d-word blocks.', size(raw, 1), sum(words));
end
nb = size(raw, 2);

S = struct();
for s = signals
    switch s
        case "timestamps"
            w = raw(first(1) + (1:words(1)), :);
            if (hdr.mainVersion == 1 && hdr.secondaryVersion >= 2) || hdr.mainVersion > 1
                S.timestamps = double(typecast(w(:), 'int32')).';
            else
                S.timestamps = double(typecast(w(:), 'uint32')).';
            end
        case "amplifier"
            S.amplifier = byChannel(raw, first(2), spb, hdr.numAmplifierChannels);
        case "aux"
            S.aux = byChannel(raw, first(3), spb / 4, hdr.numAuxInputChannels);
        case "supply"
            S.supply = raw(first(4) + (1:words(4)), :);
        case "temp"
            w = raw(first(5) + (1:words(5)), :);
            S.temp = reshape(typecast(w(:), 'int16'), words(5), nb);
        case "adc"
            S.adc = byChannel(raw, first(6), spb, hdr.numBoardADCChannels);
        case "digIn"
            S.digIn = reshape(raw(first(7) + (1:words(7)), :), 1, []);
        case "digOut"
            S.digOut = reshape(raw(first(8) + (1:words(8)), :), 1, []);
        otherwise
            error('IntanReader:sliceDataBlocks:BadSignal', 'Unknown signal "%s".', s);
    end
end
end


function X = byChannel(raw, first, m, nCh)
%byChannel  [nCh x m*nBlocks] from the nCh runs of m samples each block holds.
nb = size(raw, 2);
X = reshape(raw(first + (1:m*nCh), :), m, nCh, nb);
X = reshape(permute(X, [2 1 3]), nCh, m * nb);
end
