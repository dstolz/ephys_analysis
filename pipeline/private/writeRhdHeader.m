function writeRhdHeader(fid, Fs, ch, opts)
%writeRhdHeader  Write the header of an Intan RHD2000 file (test fixture).
%   writeRhdHeader(fid, Fs, ch) writes a complete RHD2000 header to the open
%   little-endian file FID: magic number, version, sample rate, bandwidth
%   settings, notes, board mode, reference channel and ONE signal group
%   ("Port A") holding the channels described by CH:
%     ch.ampNative, ch.ampCustom   1 x nAmp native / custom amplifier names
%     ch.auxNative, ch.auxCustom   1 x nAux aux-input names (optional; none)
%     ch.digNative, ch.digCustom   1 x nDig digital-input names (optional; none)
%     ch.digOrders                 1 x nDig native_order of each line = the bit
%                                  it occupies in the digital-input word
%   Options
%     Version   [main secondary] (default [2 0]; RHX writes 3.x, which the
%               readers parse identically)
%     Notes     1 x 3 strings (note1..note3; default empty)
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
end

ampNative = string(ch.ampNative); ampCustom = string(ch.ampCustom);
auxNative = string.empty(1,0); auxCustom = string.empty(1,0);
digNative = string.empty(1,0); digCustom = string.empty(1,0); digOrders = [];
if isfield(ch, 'auxNative'); auxNative = string(ch.auxNative); auxCustom = string(ch.auxCustom); end
if isfield(ch, 'digNative')
    digNative = string(ch.digNative); digCustom = string(ch.digCustom); digOrders = double(ch.digOrders);
end
numAmp = numel(ampNative); numAux = numel(auxNative); numDig = numel(digNative);
assert(numel(ampCustom) == numAmp && numel(auxCustom) == numAux ...
    && numel(digCustom) == numDig && numel(digOrders) == numDig, ...
    'writeRhdHeader: channel name lists must have matching lengths');

fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, opts.Version(1), 'int16');         % main version (>1 => 128 spb, int32 ts)
fwrite(fid, opts.Version(2), 'int16');         % secondary version
fwrite(fid, Fs, 'single');                     % sample_rate
fwrite(fid, 1, 'int16');                        % dsp_enabled
fwrite(fid, [1 1 7500], 'single');              % actual dsp cutoff, lower, upper bw
fwrite(fid, [1 1 7500], 'single');              % desired dsp cutoff, lower, upper bw
fwrite(fid, 0, 'int16');                        % notch_filter_mode
fwrite(fid, [1000 1000], 'single');             % desired/actual impedance test freq
writeQString(fid, char(opts.Notes(1)));         % note1
writeQString(fid, char(opts.Notes(2)));         % note2
writeQString(fid, char(opts.Notes(3)));         % note3
fwrite(fid, 0, 'int16');                        % num_temp_sensor_channels (v1.1+/v>1)
fwrite(fid, 0, 'int16');                        % board_mode (v1.3+/v>1)
if opts.Version(1) > 1
    writeQString(fid, '');                      % reference_channel (v>1)
end

% One signal group holding the amplifier, aux and digital-input channels.
fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'Port A');                    % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numAmp + numAux + numDig, 'int16'); % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels
for c = 1:numAmp
    writeRhdChannel(fid, char(ampNative(c)), char(ampCustom(c)), c-1, 0);      % signal_type 0
end
for c = 1:numAux
    writeRhdChannel(fid, char(auxNative(c)), char(auxCustom(c)), numAmp + c - 1, 1);   % signal_type 1
end
for c = 1:numDig
    writeRhdChannel(fid, char(digNative(c)), char(digCustom(c)), digOrders(c), 4);     % signal_type 4
end
end
