function writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb, opts)
%writeSyntheticRHD  Write a valid RHD2000 file with embedded data (test fixture).
%   writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb)
%   ampRaw [numAmp x nSamples] uint16 raw codes (microvolts = 0.195*(raw-32768));
%   digRaw [1 x nSamples] the digital-input word per sample: bit k carries
%   the line whose native_order is k. With the default single line "din0"
%   (native "DIN-00", native_order 0) digRaw is simply 0/1. nSamples must be
%   a multiple of spb (128 for v2+ files).
%
%   Options (all optional; the defaults reproduce the original fixture:
%   amplifier channels A-000.. named amp0.., one dig-in line, no aux)
%     AmpNames, AmpNative     1 x numAmp custom / native amplifier names
%     DigInNames              1 x nDig custom dig-in names (default "din0")
%     DigInOrders             1 x nDig native_order = bit position (default 0:nDig-1)
%     DigInNative             1 x nDig native names (default "DIN-" + order, 2 digits)
%     AuxRaw                  [numAux x nSamples/4] uint16 aux-input codes
%                             (volts = 37.4e-6 * raw), sampled at Fs/4
%     AuxNames, AuxNative     1 x numAux names (default accel1.. / A-AUX1..)
%     Version                 [main secondary] (default [2 0])
%     FirstTimestamp          int32 timestamp of the first sample (default 0;
%                             RHX continues the count across the files of a
%                             recording)
%     Notes                   1 x 3 strings
%
%   Data blocks are written in the layout the readers expect: per block the
%   int32 timestamps, the amplifier samples channel by channel, the aux
%   samples channel by channel (spb/4 each), then the dig-in words.
%
%   Shared by the test suites (intan/private is visible to functions in
%   intan/) and by makeSyntheticRecording. See also writeRhdHeader,
%   writeInfoRHD, writeDat, injectSpikes, makePhyFixture.

arguments
    ffn (1,1) string
    ampRaw
    digRaw
    Fs (1,1) double {mustBePositive}
    spb (1,1) double {mustBePositive, mustBeInteger}
    opts.AmpNames (1,:) string = string.empty(1,0)
    opts.AmpNative (1,:) string = string.empty(1,0)
    opts.DigInNames (1,:) string = "din0"
    opts.DigInOrders (1,:) double = []
    opts.DigInNative (1,:) string = string.empty(1,0)
    opts.AuxRaw = uint16.empty(0, 0)
    opts.AuxNames (1,:) string = string.empty(1,0)
    opts.AuxNative (1,:) string = string.empty(1,0)
    opts.Version (1,2) double = [2 0]
    opts.FirstTimestamp (1,1) double = 0
    opts.Notes (1,3) string = ["" "" ""]
end

numAmp = size(ampRaw, 1);
nSamples = size(ampRaw, 2);
assert(mod(nSamples, spb) == 0, 'nSamples must be a multiple of spb');
assert(mod(spb, 4) == 0, 'spb must be a multiple of 4');
nBlocks = nSamples / spb;
assert(numel(digRaw) == nSamples, 'digRaw must have one word per sample');

ch = struct();
ch.ampNative = opts.AmpNative;
if isempty(ch.ampNative); ch.ampNative = "A-" + string(compose('%03d', (0:numAmp-1).')).'; end
ch.ampCustom = opts.AmpNames;
if isempty(ch.ampCustom); ch.ampCustom = "amp" + string(0:numAmp-1); end
numAux = size(opts.AuxRaw, 1);
if numAux > 0
    assert(size(opts.AuxRaw, 2) == nSamples / 4, 'AuxRaw must have nSamples/4 columns');
    ch.auxNative = opts.AuxNative;
    if isempty(ch.auxNative); ch.auxNative = "A-AUX" + string(1:numAux); end
    ch.auxCustom = opts.AuxNames;
    if isempty(ch.auxCustom); ch.auxCustom = "accel" + string(1:numAux); end
end
nDig = numel(opts.DigInNames);
if nDig > 0
    ch.digCustom = opts.DigInNames;
    ch.digOrders = opts.DigInOrders;
    if isempty(ch.digOrders); ch.digOrders = 0:nDig-1; end
    ch.digNative = opts.DigInNative;
    if isempty(ch.digNative); ch.digNative = "DIN-" + string(compose('%02d', ch.digOrders(:))).'; end
end

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);
closer = onCleanup(@() fclose(fid));

writeRhdHeader(fid, Fs, ch, Version=opts.Version, Notes=opts.Notes);

% --- Data blocks, as one uint16 stream (each int32 timestamp = 2 words) ----
% fread reads each block as [spb, numAmp] column-major, i.e. channel 1's spb
% samples, then channel 2's, ... ; the aux block likewise with spb/4 rows.
ts  = int32(opts.FirstTimestamp + (0:nSamples-1));
tsW = reshape(typecast(ts(:), 'uint16'), 2 * spb, nBlocks);
A   = uint16(ampRaw).';                                            % [nSamples x numAmp]
ampW = reshape(permute(reshape(A, spb, nBlocks, numAmp), [1 3 2]), spb * numAmp, nBlocks);
if numAux > 0
    X = uint16(opts.AuxRaw).';                                     % [nSamples/4 x numAux]
    auxW = reshape(permute(reshape(X, spb / 4, nBlocks, numAux), [1 3 2]), spb / 4 * numAux, nBlocks);
else
    auxW = zeros(0, nBlocks, 'uint16');
end
if nDig > 0
    digW = reshape(uint16(digRaw(:)), spb, nBlocks);
else
    digW = zeros(0, nBlocks, 'uint16');
end
fwrite(fid, [tsW; ampW; auxW; digW], 'uint16');
end
