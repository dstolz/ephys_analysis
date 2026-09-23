function writeRhdHeader(fid, Fs, ch, opts)
%writeRhdHeader  Write the header of an Intan RHD2000 file (test fixture).
%   writeRhdHeader(fid, Fs, ch) writes a complete RHD2000 header to the open
%   little-endian file FID: magic number, version, sample rate, bandwidth
%   settings, notes, board mode, reference channel and ONE signal group
%   ("Port A") holding the channels described by CH:
%     ch.ampNative, ch.ampCustom   1 x nAmp native / custom amplifier names
%     ch.ampDisabledAt             positions (1-based, among nAmp + their
%                                  count) of extra DISABLED amplifier records
%                                  (optional; none)
%     ch.auxNative, ch.auxCustom   1 x nAux aux-input names (optional; none)
%     ch.supplyNative, ch.supplyCustom   supply-voltage names (optional; none)
%     ch.adcNative, ch.adcCustom   board ADC names (optional; none)
%     ch.digNative, ch.digCustom   1 x nDig digital-input names (optional; none)
%     ch.digOrders                 1 x nDig native_order of each line = the bit
%                                  it occupies in the digital-input word
%     ch.doutNative, ch.doutCustom, ch.doutOrders   digital outputs (optional)
%     ch.numTemp                   temperature sensor channels (optional; 0)
%   Options
%     Version    [main secondary] (default [2 0]; RHX writes 3.x, which the
%                readers parse identically). The fields a version lacks are
%                left out (temperature sensors before 1.1, board mode before
%                1.3, reference channel before 2.0), as the Intan software did.
%     Notes      1 x 3 strings (note1..note3; default empty)
%     NotchMode  0 (default) | 1 (50 Hz) | 2 (60 Hz) software notch filter
%     BoardMode  board mode (default 0; sets the ADC scaling)
%
%   Nothing follows the header: writeInfoRHD stops here (split layouts) and
%   writeSyntheticRHD appends the data blocks. Shared by the test suites and
%   by makeSyntheticRecording.
%
%   See also writeSyntheticRHD, writeInfoRHD, writeRhdChannel, writeQString.

arguments
    fid (1,1) double
    Fs (1,1) double {mustBePositive}
    ch (1,1) struct
    opts.Version (1,2) double = [2 0]
    opts.Notes (1,3) string = ["" "" ""]
    opts.NotchMode (1,1) double {mustBeMember(opts.NotchMode, [0 1 2])} = 0
    opts.BoardMode (1,1) double = 0
end

ampNative = string(ch.ampNative); ampCustom = string(ch.ampCustom);
[auxNative, auxCustom] = names(ch, 'aux');
[supNative, supCustom] = names(ch, 'supply');
[adcNative, adcCustom] = names(ch, 'adc');
[digNative, digCustom] = names(ch, 'dig');
[doutNative, doutCustom] = names(ch, 'dout');
digOrders = []; doutOrders = []; disabledAt = []; numTemp = 0;
if isfield(ch, 'digOrders'); digOrders = double(ch.digOrders); end
if isfield(ch, 'doutOrders'); doutOrders = double(ch.doutOrders); end
if isfield(ch, 'ampDisabledAt'); disabledAt = double(ch.ampDisabledAt); end
if isfield(ch, 'numTemp'); numTemp = double(ch.numTemp); end
numAmp = numel(ampNative); numAux = numel(auxNative); numDig = numel(digNative);
assert(numel(ampCustom) == numAmp && numel(auxCustom) == numAux ...
    && numel(digCustom) == numDig && numel(digOrders) == numDig ...
    && numel(supCustom) == numel(supNative) && numel(adcCustom) == numel(adcNative) ...
    && numel(doutCustom) == numel(doutNative) && numel(doutOrders) == numel(doutNative), ...
    'writeRhdHeader: channel name lists must have matching lengths');
v = opts.Version;

fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, v(1), 'int16');                    % main version (>1 => 128 spb, int32 ts)
fwrite(fid, v(2), 'int16');                    % secondary version
fwrite(fid, Fs, 'single');                     % sample_rate
fwrite(fid, 1, 'int16');                        % dsp_enabled
fwrite(fid, [1 1 7500], 'single');              % actual dsp cutoff, lower, upper bw
fwrite(fid, [1 1 7500], 'single');              % desired dsp cutoff, lower, upper bw
fwrite(fid, opts.NotchMode, 'int16');           % notch_filter_mode
fwrite(fid, [1000 1000], 'single');             % desired/actual impedance test freq
writeQString(fid, char(opts.Notes(1)));         % note1
writeQString(fid, char(opts.Notes(2)));         % note2
writeQString(fid, char(opts.Notes(3)));         % note3
if (v(1) == 1 && v(2) >= 1) || v(1) > 1
    fwrite(fid, numTemp, 'int16');              % num_temp_sensor_channels (v1.1+)
end
if (v(1) == 1 && v(2) >= 3) || v(1) > 1
    fwrite(fid, opts.BoardMode, 'int16');       % board_mode (v1.3+)
end
if v(1) > 1
    writeQString(fid, '');                      % reference_channel (v2.0+)
end

% One signal group holding every channel record.
numRec = numAmp + numel(disabledAt) + numAux + numel(supNative) + numel(adcNative) + numDig + numel(doutNative);
fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'Port A');                    % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numRec, 'int16');                   % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels
c = 0;
for r = 1:numAmp + numel(disabledAt)
    if ismember(r, disabledAt)
        writeRhdChannel(fid, sprintf('A-9%02d', r), sprintf('off%d', r), 900 + r, 0, false);
    else
        c = c + 1;
        writeRhdChannel(fid, char(ampNative(c)), char(ampCustom(c)), c-1, 0);   % signal_type 0
    end
end
for c = 1:numAux
    writeRhdChannel(fid, char(auxNative(c)), char(auxCustom(c)), numAmp + c - 1, 1);   % signal_type 1
end
for c = 1:numel(supNative)
    writeRhdChannel(fid, char(supNative(c)), char(supCustom(c)), c - 1, 2);           % signal_type 2
end
for c = 1:numel(adcNative)
    writeRhdChannel(fid, char(adcNative(c)), char(adcCustom(c)), c - 1, 3);           % signal_type 3
end
for c = 1:numDig
    writeRhdChannel(fid, char(digNative(c)), char(digCustom(c)), digOrders(c), 4);     % signal_type 4
end
for c = 1:numel(doutNative)
    writeRhdChannel(fid, char(doutNative(c)), char(doutCustom(c)), doutOrders(c), 5);  % signal_type 5
end
end


function [native, custom] = names(ch, kind)
%names  The optional native / custom name lists of one channel kind (empty when absent).
native = string.empty(1,0); custom = string.empty(1,0);
if isfield(ch, kind + "Native")
    native = string(ch.(kind + "Native")); custom = string(ch.(kind + "Custom"));
end
end
