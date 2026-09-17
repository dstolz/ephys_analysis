function writeInfoRHD(ffn, numAmp, Fs, numAux, opts)
%writeInfoRHD  Write a header-only info.rhd for the split layouts (test fixture).
%   writeInfoRHD(ffn, numAmp, Fs) writes the header of a split-format
%   recording (no data blocks follow). Declares numAmp amplifier channels
%   (native names A-000..A-00N, so amp-A-00x.dat filenames line up; custom
%   names amp0..) plus one bit-0 dig-in line "din0" (native "DIN-00"); no adc.
%   writeInfoRHD(ffn, numAmp, Fs, numAux) also declares numAux aux input
%   (accelerometer) channels, native A-AUX1.., custom accel1.. (default 0).
%
%   Options (as in writeSyntheticRHD): AmpNames, AmpNative, DigInNames,
%   DigInOrders, DigInNative, AuxNames, AuxNative, Version, Notes.
%
%   See also writeRhdHeader, writeSyntheticRHD, writeDat.

arguments
    ffn (1,1) string
    numAmp (1,1) double {mustBeInteger, mustBePositive}
    Fs (1,1) double {mustBePositive}
    numAux (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    opts.AmpNames (1,:) string = string.empty(1,0)
    opts.AmpNative (1,:) string = string.empty(1,0)
    opts.DigInNames (1,:) string = "din0"
    opts.DigInOrders (1,:) double = []
    opts.DigInNative (1,:) string = string.empty(1,0)
    opts.AuxNames (1,:) string = string.empty(1,0)
    opts.AuxNative (1,:) string = string.empty(1,0)
    opts.Version (1,2) double = [2 0]
    opts.Notes (1,3) string = ["" "" ""]
end

ch = struct();
ch.ampNative = opts.AmpNative;
if isempty(ch.ampNative); ch.ampNative = "A-" + string(compose('%03d', (0:numAmp-1).')).'; end
ch.ampCustom = opts.AmpNames;
if isempty(ch.ampCustom); ch.ampCustom = "amp" + string(0:numAmp-1); end
if numAux > 0
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
writeRhdHeader(fid, Fs, ch, Version=opts.Version, Notes=opts.Notes);   % header only
end
