function writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb, opts)
%writeSyntheticRHD  Write a valid RHD2000 file with embedded data (test fixture).
%   writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb)
%   ampRaw [numAmp x nSamples] uint16 raw codes (microvolts = 0.195*(raw-32768));
%   digRaw [1 x nSamples] the digital-input word per sample: bit k carries
%   the line whose native_order is k. With the default single line "din0"
%   (native "DIN-00", native_order 0) digRaw is simply 0/1. nSamples must be
%   a multiple of spb (128 for v2+ files, 60 for v1 files).
%
%   Options (all optional; the defaults reproduce the original fixture:
%   amplifier channels A-000.. named amp0.., one dig-in line, no aux)
%     AmpNames, AmpNative     1 x numAmp custom / native amplifier names
%     DisabledAmp             positions of extra disabled amplifier records
%                             in the header (no data; see writeRhdHeader)
%     DigInNames              1 x nDig custom dig-in names (default "din0";
%                             "" or empty for none)
%     DigInOrders             1 x nDig native_order = bit position (default 0:nDig-1)
%     DigInNative             1 x nDig native names (default "DIN-" + order, 2 digits)
%     AuxRaw                  [numAux x nSamples/4] uint16 aux-input codes
%                             (volts = 37.4e-6 * raw), sampled at Fs/4
%     AuxNames, AuxNative     1 x numAux names (default accel1.. / A-AUX1..)
%     SupplyRaw               [nSupply x nBlocks] uint16 supply-voltage codes
%                             (one per block; names VDD1.. / A-VDD1..)
%     TempRaw                 [nTemp x nBlocks] int16 temperature codes
%     AdcRaw                  [nADC x nSamples] uint16 board ADC codes
%                             (names adc1.. / ANALOG-IN-1..)
%     DigOutRaw               [1 x nSamples] digital-output word; lines
%                             DigOutOrders (default one line, bit 0)
%     Version                 [main secondary] (default [2 0]); files before
%                             1.2 store the timestamps as uint32
%     NotchMode, BoardMode    header settings (see writeRhdHeader)
%     FirstTimestamp          timestamp of the first sample (default 0;
%                             RHX continues the count across the files of a
%                             recording)
%     Notes                   1 x 3 strings
%
%   Data blocks are written in the layout the readers expect: per block the
%   timestamps, the amplifier samples channel by channel, the aux samples
%   channel by channel (spb/4 each), one supply and one temperature word per
%   channel, the ADC samples channel by channel, then the dig-in and dig-out
%   words.
%
%   Shared by the test suites (pipeline/private is visible to functions in
%   pipeline/) and by makeSyntheticRecording. See also writeRhdHeader,
%   writeInfoRHD, writeDat, injectSpikes, makePhyFixture.

arguments
    ffn (1,1) string
    ampRaw
    digRaw
    Fs (1,1) double {mustBePositive}
    spb (1,1) double {mustBePositive, mustBeInteger}
    opts.AmpNames (1,:) string = string.empty(1,0)
    opts.AmpNative (1,:) string = string.empty(1,0)
    opts.DisabledAmp (1,:) double = []
    opts.DigInNames (1,:) string = "din0"
    opts.DigInOrders (1,:) double = []
    opts.DigInNative (1,:) string = string.empty(1,0)
    opts.AuxRaw = uint16.empty(0, 0)
    opts.AuxNames (1,:) string = string.empty(1,0)
    opts.AuxNative (1,:) string = string.empty(1,0)
    opts.SupplyRaw = uint16.empty(0, 0)
    opts.TempRaw = int16.empty(0, 0)
    opts.AdcRaw = uint16.empty(0, 0)
    opts.DigOutRaw = uint16.empty(0, 0)
    opts.DigOutOrders (1,:) double = 0
    opts.Version (1,2) double = [2 0]
    opts.NotchMode (1,1) double = 0
    opts.BoardMode (1,1) double = 0
    opts.FirstTimestamp (1,1) double = 0
    opts.Notes (1,3) string = ["" "" ""]
end

numAmp = size(ampRaw, 1);
nSamples = size(ampRaw, 2);
assert(mod(nSamples, spb) == 0, 'nSamples must be a multiple of spb');
assert(mod(spb, 4) == 0, 'spb must be a multiple of 4');
nBlocks = nSamples / spb;
opts.DigInNames = opts.DigInNames(opts.DigInNames ~= "");
nDig = numel(opts.DigInNames);
assert(nDig == 0 || numel(digRaw) == nSamples, 'digRaw must have one word per sample');

ch = struct();
ch.ampNative = opts.AmpNative;
if isempty(ch.ampNative); ch.ampNative = "A-" + string(compose('%03d', (0:numAmp-1).')).'; end
ch.ampCustom = opts.AmpNames;
if isempty(ch.ampCustom); ch.ampCustom = "amp" + string(0:numAmp-1); end
ch.ampDisabledAt = opts.DisabledAmp;
numAux = size(opts.AuxRaw, 1);
if numAux > 0
    assert(size(opts.AuxRaw, 2) == nSamples / 4, 'AuxRaw must have nSamples/4 columns');
    ch.auxNative = opts.AuxNative;
    if isempty(ch.auxNative); ch.auxNative = "A-AUX" + string(1:numAux); end
    ch.auxCustom = opts.AuxNames;
    if isempty(ch.auxCustom); ch.auxCustom = "accel" + string(1:numAux); end
end
numSup = size(opts.SupplyRaw, 1);
if numSup > 0
    assert(size(opts.SupplyRaw, 2) == nBlocks, 'SupplyRaw must have one column per block');
    ch.supplyNative = "A-VDD" + string(1:numSup);
    ch.supplyCustom = "VDD" + string(1:numSup);
end
ch.numTemp = size(opts.TempRaw, 1);
assert(ch.numTemp == 0 || size(opts.TempRaw, 2) == nBlocks, 'TempRaw must have one column per block');
numAdc = size(opts.AdcRaw, 1);
if numAdc > 0
    assert(size(opts.AdcRaw, 2) == nSamples, 'AdcRaw must have one column per sample');
    ch.adcNative = "ANALOG-IN-" + string(1:numAdc);
    ch.adcCustom = "adc" + string(1:numAdc);
end
if nDig > 0
    ch.digCustom = opts.DigInNames;
    ch.digOrders = opts.DigInOrders;
    if isempty(ch.digOrders); ch.digOrders = 0:nDig-1; end
    ch.digNative = opts.DigInNative;
    if isempty(ch.digNative); ch.digNative = "DIN-" + string(compose('%02d', ch.digOrders(:))).'; end
end
hasDout = ~isempty(opts.DigOutRaw);
if hasDout
    assert(numel(opts.DigOutRaw) == nSamples, 'DigOutRaw must have one word per sample');
    ch.doutOrders = opts.DigOutOrders;
    ch.doutNative = "DIGITAL-OUT-" + string(compose('%02d', ch.doutOrders(:) + 1)).';
    ch.doutCustom = "dout" + string(ch.doutOrders);
end

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);
closer = onCleanup(@() fclose(fid));

writeRhdHeader(fid, Fs, ch, Version=opts.Version, Notes=opts.Notes, ...
    NotchMode=opts.NotchMode, BoardMode=opts.BoardMode);

% --- Data blocks, as one uint16 stream (each 32-bit timestamp = 2 words) ----
% fread reads each block as [spb, numAmp] column-major, i.e. channel 1's spb
% samples, then channel 2's, ... ; the aux and ADC blocks likewise.
v = opts.Version;
if (v(1) == 1 && v(2) >= 2) || v(1) > 1
    ts = int32(opts.FirstTimestamp + (0:nSamples-1));
else
    ts = uint32(opts.FirstTimestamp + (0:nSamples-1));        % before v1.2: unsigned
end
tsW = reshape(typecast(ts(:), 'uint16'), 2 * spb, nBlocks);
ampW  = perChannel(ampRaw, spb, nBlocks);
auxW  = perChannel(opts.AuxRaw, spb / 4, nBlocks);
supW  = reshape(uint16(opts.SupplyRaw), numSup, nBlocks);
tempW = reshape(typecast(reshape(int16(opts.TempRaw), [], 1), 'uint16'), ch.numTemp, nBlocks);
adcW  = perChannel(opts.AdcRaw, spb, nBlocks);
if nDig > 0
    digW = reshape(uint16(digRaw(:)), spb, nBlocks);
else
    digW = zeros(0, nBlocks, 'uint16');
end
if hasDout
    doutW = reshape(uint16(opts.DigOutRaw(:)), spb, nBlocks);
else
    doutW = zeros(0, nBlocks, 'uint16');
end
fwrite(fid, [tsW; ampW; auxW; supW; tempW; adcW; digW; doutW], 'uint16');
end


function W = perChannel(raw, m, nBlocks)
%perChannel  [nCh x m*nBlocks] codes -> [m*nCh x nBlocks] block words, channel by channel.
nCh = size(raw, 1);
if nCh == 0
    W = zeros(0, nBlocks, 'uint16');
    return
end
A = uint16(raw).';                                                  % [m*nBlocks x nCh]
W = reshape(permute(reshape(A, m, nBlocks, nCh), [1 3 2]), m * nCh, nBlocks);
end
