function [M, units] = templateConversion(folder, nC)
%templateConversion  X * M puts [nS x nC] whitened Kilosort4 data in UNITS.
%   Kilosort4 whitens the data it sorts as W * X (X [channel x time]) and
%   saves inv(W) as whitening_mat_inv.npy, so a [time x channel] template
%   (or a window of its whitened data) goes back to the data's units as
%   X * inv(W).'. W is not symmetric (each row is one channel's local
%   whitening filter), so the transpose matters. The run's settings.json
%   then undoes Kilosort4's own scale and invert_sign and gives the .bin's
%   scale (bin_scale, runKilosort). M is [] (keep X as stored, UNITS
%   "whitened") without a usable whitening_mat_inv.npy; UNITS is otherwise
%   "uV" (bin_scale known) or "bin".
%
%   See also EphysDataset.readPhyUnits, EphysDataset.readPhyWaveforms.
M = []; units = "whitened";
f = fullfile(folder, 'whitening_mat_inv.npy');
if ~isfile(f); return; end
Winv = double(readNPY(f));
if ~isequal(size(Winv), [nC nC]); return; end
factor = 1;
units = "bin";
cfg = readJsonFile(fullfile(folder, 'settings.json'), ErrorOnFail=false);
if isstruct(cfg)
    if isfield(cfg, 'invert_sign') && isequal(cfg.invert_sign, true)
        factor = -factor;
    end
    if isfield(cfg, 'scale') && isFactor(cfg.scale)
        factor = factor / cfg.scale;
    end
    if isfield(cfg, 'bin_scale') && isFactor(cfg.bin_scale)
        factor = factor / cfg.bin_scale;
        units = "uV";
    end
end
M = Winv.' * factor;
end


function tf = isFactor(v)
%isFactor  A finite, non-zero numeric scalar.
tf = isnumeric(v) && isscalar(v) && isfinite(v) && v ~= 0;
end
