function writeInfoRHD(ffn, numAmp, Fs)
%writeInfoRHD  Write a header-only v2.0 info.rhd (test fixture).
%   writeInfoRHD(ffn, numAmp, Fs) writes the header of a split-format
%   recording (no data blocks follow). Declares numAmp amplifier channels
%   (native names A-000..A-00N, so amp-A-00x.dat filenames line up) plus one
%   bit-0 dig-in line; no aux/adc.
%
%   See also writeSyntheticRHD, writeDat.

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);

fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, 2, 'int16');                       % main version (>1)
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
fwrite(fid, 0, 'int16');                        % num_temp_sensor_channels
fwrite(fid, 0, 'int16');                        % board_mode
writeQString(fid, '');                          % reference_channel (v>1)

fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'PortA');                     % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numAmp + 1, 'int16');               % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels
for c = 1:numAmp
    writeRhdChannel(fid, sprintf('A-%03d', c-1), sprintf('amp%d', c-1), c-1, 0);
end
writeRhdChannel(fid, 'DIN-00', 'din0', 0, 4);   % dig-in, native_order 0

fclose(fid);   % header only - no data blocks follow
end
