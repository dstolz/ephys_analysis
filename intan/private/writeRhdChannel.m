function writeRhdChannel(fid, nativeName, customName, nativeOrder, signalType)
%writeRhdChannel  One channel record of an RHD2000 header (test fixture).
%   signalType 0 = amplifier, 4 = board digital input.
writeQString(fid, nativeName);
writeQString(fid, customName);
fwrite(fid, nativeOrder, 'int16');   % native_order
fwrite(fid, 0, 'int16');             % custom_order
fwrite(fid, signalType, 'int16');    % signal_type
fwrite(fid, 1, 'int16');             % channel_enabled
fwrite(fid, 0, 'int16');             % chip_channel
fwrite(fid, 0, 'int16');             % board_stream
fwrite(fid, 0, 'int16');             % voltage_trigger_mode
fwrite(fid, 0, 'int16');             % voltage_threshold
fwrite(fid, 0, 'int16');             % digital_trigger_channel
fwrite(fid, 0, 'int16');             % digital_edge_polarity
fwrite(fid, 0, 'single');            % electrode_impedance_magnitude
fwrite(fid, 0, 'single');            % electrode_impedance_phase
end
