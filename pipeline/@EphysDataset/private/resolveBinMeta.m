function [nChanBin, fsVal, binScale, binRef] = resolveBinMeta(binFile, opts, obj, who)
%resolveBinMeta  n_chan_bin, fs, units per uV and the common reference
%   ("none" | "car" | "cmr"; "" = not recorded) of a .bin, from its sidecar.
%   OPTS.NChanBin / OPTS.Fs (NaN = not given) win; the dataset's metadata
%   fills what the sidecar does not say. WHO ("runKilosort",
%   "runSpikeInterface") names the caller in the warning / error identifiers.
nChanBin = opts.NChanBin;
fsVal    = opts.Fs;
binScale = NaN;
binRef   = "";
% Try the .bin JSON sidecar
[d, n] = fileparts(binFile);
sidecar = fullfile(d, [n '.json']);
if isfile(sidecar)
    try
        meta = jsondecode(fileread(sidecar));
        if isnan(nChanBin) && isfield(meta, 'n_chan_bin'); nChanBin = meta.n_chan_bin; end
        if isnan(fsVal)    && isfield(meta, 'fs');         fsVal    = meta.fs;         end
        if isfield(meta, 'scale') && isnumeric(meta.scale) && isscalar(meta.scale)
            binScale = double(meta.scale);
        end
        if isfield(meta, 'reference') && isstruct(meta.reference) && isfield(meta.reference, 'mode')
            binRef = string(meta.reference.mode);
        end
    catch ME
        warning(['EphysDataset:' char(who) ':BadSidecar'], ...
            'Cannot read the .bin sidecar %s (%s); n_chan_bin and fs fall back to the dataset''s metadata.', ...
            sidecar, ME.message);
    end
end
if isnan(nChanBin); nChanBin = obj.NumChannels; end
if isnan(fsVal);    fsVal    = obj.Fs;          end
if isnan(nChanBin) || isnan(fsVal)
    error(['EphysDataset:' char(who) ':UnknownBinMeta'], ...
        'Could not determine n_chan_bin/fs; pass NChanBin/Fs or write the .bin sidecar.');
end
end
