function writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb)
%writeSyntheticRHD  Write a minimal valid v2.0 RHD2000 file (test fixture).
%   writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb)
%   ampRaw [numAmp x nSamples] uint16 raw codes (microvolts = 0.195*(raw-32768));
%   digRaw [1 x nSamples] (bit 0 of the single dig-in line "DIN-00"/"din0").
%   numAmp amplifier channels named A-000.. (custom names amp0..), 1 dig-in
%   line, no aux/adc/supply/temp/dig-out. nSamples must be a multiple of spb
%   (128 for v2 files).
%
%   Shared by the test suites (intan/private is visible to functions in
%   intan/). See also writeInfoRHD, writeDat, injectSpikes, makePhyFixture.

numAmp = size(ampRaw,1);
nSamples = size(ampRaw,2);
nBlocks = nSamples / spb;
assert(mod(nSamples, spb) == 0, 'nSamples must be a multiple of spb');

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);

% --- Header ---
fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, 2, 'int16');                       % main version (>1 => 128 spb, int32 ts)
fwrite(fid, 0, 'int16');                       % secondary version
fwrite(fid, Fs, 'single');                     % sample_rate
fwrite(fid, 1, 'int16');                        % dsp_enabled
fwrite(fid, [1 1 7500], 'single');              % actual dsp cutoff, lower, upper bw
fwrite(fid, [1 1 7500], 'single');              % desired dsp cutoff, lower, upper bw
fwrite(fid, 0, 'int16');                        % notch_filter_mode
fwrite(fid, [1000 1000], 'single');             % desired/actual impedance test freq
writeQString(fid, '');                          % note1
writeQString(fid, '');                          % note2
writeQString(fid, '');                          % note3
fwrite(fid, 0, 'int16');                        % num_temp_sensor_channels (v1.1+/v>1)
fwrite(fid, 0, 'int16');                        % board_mode (v1.3+/v>1)
writeQString(fid, '');                          % reference_channel (v>1)

% One signal group holding numAmp amplifier channels + 1 dig-in
fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'PortA');                     % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numAmp + 1, 'int16');               % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels

for c = 1:numAmp
    writeRhdChannel(fid, sprintf('A-%03d', c-1), sprintf('amp%d', c-1), c-1, 0); % signal_type 0
end
% dig-in line, native_order 0
writeRhdChannel(fid, 'DIN-00', 'din0', 0, 4);   % signal_type 4

% --- Data blocks (channel-major amplifier per block, matching the reader) ---
for blk = 1:nBlocks
    cols = (blk-1)*spb + (1:spb);
    fwrite(fid, cols - 1, 'int32');             % timestamps (int32 for v>1)
    % amplifier: fread reads [spb, numAmp] column-major => write channel-major
    ampBlock = ampRaw(:, cols).';               % [spb x numAmp]
    fwrite(fid, ampBlock, 'uint16');            % column-major => ch1 spb samples, ch2...
    % dig-in raw uint16 (bit 0 carries the line)
    fwrite(fid, digRaw(cols), 'uint16');
end

fclose(fid);
end
