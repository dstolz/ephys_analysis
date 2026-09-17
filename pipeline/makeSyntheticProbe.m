function p = makeSyntheticProbe(nChan, opts)
%makeSyntheticProbe  A Kilosort4 probe map for a synthetic recording.
%   P = makeSyntheticProbe(nChan) returns the probe struct (chanMap, xc, yc,
%   kcoords, n_chan, notes) of a multi-shank linear array: shanks of
%   SitesPerShank sites (default 8) at Pitch microns (default 25), shanks
%   ShankSpacing microns apart (default 200), sites staggered by 8 microns
%   in x so the layout is not a plain line. Channel c (0-based) is site c:
%   the map is the identity, so channel numbers, .bin rows and probe sites
%   agree, as in the lab's H64LP maps.
%
%   P = makeSyntheticProbe(nChan, File=f) also writes the JSON (the shape
%   kilosort.io.load_probe accepts, see intan/probes/README.md) to F.
%
%   See also makeSyntheticRecording, makeSyntheticProject.

arguments
    nChan (1,1) double {mustBeInteger, mustBePositive}
    opts.SitesPerShank (1,1) double {mustBeInteger, mustBePositive} = 8
    opts.Pitch (1,1) double {mustBePositive} = 25
    opts.ShankSpacing (1,1) double {mustBePositive} = 200
    opts.File (1,1) string = ""
end

c = (0:nChan-1).';
shank = floor(c / opts.SitesPerShank);
site  = mod(c, opts.SitesPerShank);
p = struct();
p.notes   = sprintf("Synthetic %d-channel probe: %d shank(s) of up to %d sites, %g um pitch (makeSyntheticProbe).", ...
    nChan, max(shank) + 1, opts.SitesPerShank, opts.Pitch);
p.chanMap = c.';
p.xc      = (shank * opts.ShankSpacing + 8 * mod(site, 2)).';
p.yc      = (site * opts.Pitch).';
p.kcoords = shank.';
p.n_chan  = nChan;

if opts.File ~= ""
    writeJsonFile(opts.File, p);
end
end
