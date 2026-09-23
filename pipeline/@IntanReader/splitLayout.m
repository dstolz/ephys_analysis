function L = splitLayout(obj)
%splitLayout  Resolve the on-disk layout of a split-format Intan recording.
%   L = ds.splitLayout() inspects a "one-file-per-signal" or "one-file-per-
%   channel" folder (info.rhd header + separate *.dat data files) and returns a
%   struct describing where the amplifier (and, best-effort, digital-in / board
%   ADC / aux) samples live and how many there are. The result is cached on the
%   object (cleared by discoverFiles) so the per-window readers can be called
%   many times cheaply.
%
%   Unlike the traditional embedded-data *.rhd format, the split formats keep the
%   header in info.rhd (no data blocks) and the amplifier samples in flat int16
%   files:
%     one-file-per-signal   amplifier.dat  [nChan x nSamp] int16, channel-major
%                           per sample (channel index varies fastest on disk)
%     one-file-per-channel  amp-<native>.dat  one int16 file per amplifier channel
%   In both layouts microvolts = 0.195 * int16 (the samples are already centered,
%   so there is NO 32768 offset, unlike the offset-binary uint16 in the *.rhd
%   blocks). Sample counts are derived from the .dat file size(s), not the header
%   (which carries no data).
%
%   Fields
%   ------
%     format       "one-file-per-signal" | "one-file-per-channel"
%     folder       recording folder
%     headerFile   info.rhd full path
%     Fs           amplifier sample rate (Hz)
%     nChan        amplifier channel count
%     nSamp        amplifier samples (from .dat size)
%     boardMode    board mode (ADC scaling, from header)
%     ampCustom / ampNative   1xnChan amplifier names (header order = file order)
%     digInNames / digInNative / digInOrders  dig-in custom names, native names
%                  and native_order bit positions
%     numADC / numAux           board ADC / aux input channel counts
%     auxCustom / auxNative     1xnAux aux input names
%     ampFile      amplifier.dat path (one-file-per-signal) or ""
%     ampFiles     1xnChan per-channel paths (one-file-per-channel) or empty
%     timeFile     time.dat path
%     digInFile    digitalin.dat path (one-file-per-signal) or ""
%     digInFiles   one-file-per-channel: 1 x nDig per-line files, found as
%                  board-<native name>.dat (RHX: board-DIGITAL-IN-01.dat),
%                  else board-DIN-<native_order, 2 digits>.dat (the older
%                  RHD2000 Interface); "" for a line with neither. Empty for
%                  one-file-per-signal
%     adcFile      analogin.dat path (one-file-per-signal) or ""
%     auxFile      auxiliary.dat path (one-file-per-signal) or ""
%
%   See also EphysDataset.detectFormat, EphysDataset.readSplitWindow,
%   EphysDataset.readSplitAll, IntanReader.parseIntanHeader.

arguments
    obj (1,1) IntanReader
end

if ~isempty(obj.pSplitLayout)
    L = obj.pSplitLayout;
    return
end

fmt = obj.RecordingFormat;
if fmt ~= "one-file-per-signal" && fmt ~= "one-file-per-channel"
    error('IntanReader:splitLayout:NotSplit', ...
        'splitLayout only applies to split formats (got "%s").', fmt);
end

folder  = char(obj.Folder);
hdrFile = fullfile(folder, 'info.rhd');
if ~isfile(hdrFile)
    error('IntanReader:splitLayout:NoHeader', ...
        'No info.rhd header found in %s', folder);
end
hdr = IntanReader.parseIntanHeader(hdrFile);

L = struct();
L.format      = fmt;
L.folder      = string(folder);
L.headerFile  = string(hdrFile);
L.Fs          = hdr.sampleRate;
L.nChan       = hdr.numAmplifierChannels;
L.boardMode   = hdr.boardMode;
L.ampCustom   = hdr.channelNames;
L.ampNative   = hdr.nativeNames;
L.digInNames  = hdr.digInNames;
L.digInNative = hdr.digInNativeNames;
L.digInOrders = hdr.digInNativeOrders;
L.numADC      = hdr.numBoardADCChannels;
L.numAux      = hdr.numAuxInputChannels;
L.auxCustom   = hdr.auxNames;
L.auxNative   = hdr.auxNativeNames;
L.timeFile    = string(fullfile(folder, 'time.dat'));

% Defaults (overwritten per format below)
L.ampFile    = "";
L.ampFiles   = string.empty(1,0);
L.digInFile  = "";
L.digInFiles = string.empty(1,0);
L.adcFile    = "";
L.auxFile    = "";

switch fmt
    case "one-file-per-signal"
        L.ampFile = string(fullfile(folder, 'amplifier.dat'));
        if ~isfile(L.ampFile)
            error('IntanReader:splitLayout:NoAmplifier', ...
                'Missing amplifier.dat in %s', folder);
        end
        if L.nChan <= 0
            error('IntanReader:splitLayout:NoChannels', ...
                'info.rhd in %s reports no amplifier channels.', folder);
        end
        d = dir(char(L.ampFile));
        L.nSamp = floor(d.bytes / (2 * L.nChan));   % int16 = 2 bytes/sample/chan
        L.ampDatenum = d.datenum;
        L.digInFile  = string(fullfile(folder, 'digitalin.dat'));
        L.adcFile    = string(fullfile(folder, 'analogin.dat'));
        L.auxFile    = string(fullfile(folder, 'auxiliary.dat'));

    case "one-file-per-channel"
        if L.nChan <= 0
            error('IntanReader:splitLayout:NoChannels', ...
                'info.rhd in %s reports no amplifier channels.', folder);
        end
        files = strings(1, L.nChan);
        for k = 1:L.nChan
            files(k) = string(fullfile(folder, "amp-" + L.ampNative(k) + ".dat"));
        end
        if ~isfile(files(1))
            error('IntanReader:splitLayout:NoAmplifier', ...
                'Missing per-channel amplifier file %s', files(1));
        end
        L.ampFiles = files;
        d = dir(char(files(1)));
        L.nSamp = floor(d.bytes / 2);               % int16 = 2 bytes/sample
        L.ampDatenum = d.datenum;
        % Per-line digital-in files: RHX names them after the line's native
        % name, the RHD2000 Interface after its native_order.
        if ~isempty(L.digInOrders)
            df = strings(1, numel(L.digInOrders));
            for k = 1:numel(L.digInOrders)
                cand = string(fullfile(folder, ["board-" + L.digInNative(k) + ".dat", ...
                    sprintf("board-DIN-%02d.dat", L.digInOrders(k))]));
                hit = find(isfile(cand), 1);
                if ~isempty(hit); df(k) = cand(hit); end
            end
            L.digInFiles = df;
        end
end

obj.pSplitLayout = L;
end
