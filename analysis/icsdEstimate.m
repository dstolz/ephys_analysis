function [csd, z, info] = icsdEstimate(pots, depthMm, opts)
%icsdEstimate  Inverse current source density of laminar potentials with the iCSD toolbox.
%   [CSD, Z] = icsdEstimate(POTS, DEPTH) estimates the CSD along a linear
%   array from POTS, [nChan x nTime] potentials in V (or [nChan x nTime x
%   nGroups]: every page at once, the methods are linear), the channels at
%   DEPTH (mm below the top channel, ascending; epochMatrixCSD's depth_mm),
%   with one of the iCSD toolbox's methods (Pettersen, Devor, Ulbert, Dale
%   & Einevoll 2006, J Neurosci Methods 154:116, the CSDplotter methods as
%   https://github.com/dstolz/iCSD packages them; add its folder, with
%   methods/, to the path):
%     Method "spline" (default)  cubic-spline iCSD (iCSD_spline): the CSD
%                      continuous between the channels, Gaussian-smoothed,
%                      on NumOut points (50)
%            "delta"   delta-source iCSD (iCSD_delta): a sheet source at
%                      each channel; 3-point smoothing with B0, B1; equal
%                      spacing required
%            "step"    step iCSD (iCSD_step): a constant source between
%                      channels, Gaussian-smoothed, on a fine grid; equal
%                      spacing required
%            "standard" the second spatial difference (iCSD_standard, with
%                      Vaknin's duplicated end channels, the mean spacing),
%                      3-point smoothed
%   CSD is [nZ x nTime (x nGroups)] in uA/mm^3 (the toolbox's A/m^3 / 1000),
%   positive = source, Z the nZ depths, mm below the top channel (the
%   channels' own for delta and standard; the inner channels for standard
%   with Vaknin false).
%
%   Options (SI, as the toolbox): Cond 0.3 S/m (the tissue), CondTop (the
%   medium above the surface; Cond by default: one layer), Diam 0.5e-3 m
%   (the active column, delta / step / spline), GaussSigma 0.1e-3 m (the
%   smoothing of spline and step; 0 for none), NumOut 50 (spline's points),
%   B0 0.54 and B1 0.23 (delta's and standard's 3-point filter; B1 = 0 for
%   none), Vaknin true (standard). Surface is the depth of the top channel
%   below the surface, mm (default: one channel spacing); it matters only
%   when CondTop differs from Cond (the mirror sources), and Z stays
%   relative to the top channel. The spline's imaginary top node sits at
%   the surface, so Surface must be > 0 for "spline".
%
%   INFO: method, the options used, h_mm (the spacing), uniform (all steps
%   within 1%; "step" and "delta" refuse otherwise, "standard" uses the
%   mean), and units.
%
%   Errors: icsdEstimate:NoToolbox (iCSD_<method> not on the path),
%   icsdEstimate:Size (rows of POTS and DEPTH differ), icsdEstimate:Depths
%   (not ascending), icsdEstimate:NotUniform (Method "step" or "delta" on
%   unequal spacing), icsdEstimate:Surface (Method "spline" with Surface
%   <= 0).
%
%   See also epochMatrixCSD, sessionDataCSD, kcsdEstimate, laminarColumns.

arguments
    pots {mustBeNumeric}
    depthMm (:,1) double {mustBeFinite}
    opts.Method (1,1) string {mustBeMember(opts.Method, ["spline" "delta" "step" "standard"])} = "spline"
    opts.Cond (1,1) double {mustBePositive} = 0.3
    opts.CondTop double = []
    opts.Diam (1,1) double {mustBePositive} = 0.5e-3
    opts.GaussSigma (1,1) double {mustBeNonnegative} = 0.1e-3
    opts.NumOut (1,1) double {mustBeInteger, mustBePositive} = 50
    opts.B0 (1,1) double = 0.54
    opts.B1 (1,1) double = 0.23
    opts.Vaknin (1,1) logical = true
    opts.Surface double = []
end
method = opts.Method;
fn = "iCSD_" + method;
if ~exist(fn, 'file')
    error('icsdEstimate:NoToolbox', ...
        '%s is not on the path: add the iCSD toolbox folder (with its methods/ subfolder), e.g. addpath(genpath(''c:\\src\\iCSD'')).', fn);
end
nChan = numel(depthMm);
sz = size(pots);
if sz(1) ~= nChan
    error('icsdEstimate:Size', 'POTS has %d rows for %d depths.', sz(1), nChan);
end
if any(diff(depthMm) <= 0)
    error('icsdEstimate:Depths', 'DEPTH must ascend (mm below the top channel, laminarColumns'' depth_mm).');
end
steps = diff(depthMm);
h = median(steps);
uniform = all(abs(steps - h) <= 0.01 * h);
if any(method == ["step" "delta"]) && ~uniform
    error('icsdEstimate:NotUniform', ...
        'The %s iCSD needs equally spaced channels (steps %.4g to %.4g mm): use "spline", or leave a gap''s neighbors out.', ...
        method, min(steps), max(steps));
end
condTop = opts.CondTop;
if isempty(condTop); condTop = opts.Cond; end
surface = opts.Surface;
if isempty(surface); surface = h; end
if method == "spline" && surface <= 0
    error('icsdEstimate:Surface', ...
        'The spline iCSD starts at the surface above the top channel: Surface must be > 0 mm (got %.4g).', surface);
end
pos = depthMm + surface;                          % mm below the surface, positive
Y = double(reshape(pots, nChan, []));             % every page at once
% a page without data (a group without epochs is all NaN) is left NaN
finiteCol = all(isfinite(Y), 1);
if ~any(finiteCol)
    error('icsdEstimate:NoData', 'POTS holds no finite column (every group without epochs?).');
end
Yall = Y;
Y = Y(:, finiteCol);

switch method
    case "spline"
        [C, zs] = iCSD_spline(Y, pos(:).', cond=opts.Cond, cond_top=condTop, diam=opts.Diam, ...
            gauss_sigma=opts.GaussSigma, num_out_zs=opts.NumOut);
    case "delta"
        [C, zs] = iCSD_delta(Y, pos(:), opts.Cond, condTop, opts.Diam, opts.B0, opts.B1);
    case "step"
        [C, zs] = iCSD_step(Y, pos(:), cond=opts.Cond, cond_top=condTop, diam=opts.Diam, ...
            gauss_sigma=opts.GaussSigma);
    case "standard"
        [C, zs] = iCSD_standard(Y, pos(:), opts.B0, opts.B1, opts.Cond, applyVaknin=opts.Vaknin);
end
z = zs(:) - surface;                              % back to mm below the top channel
Call = NaN(numel(z), size(Yall, 2));
Call(:, finiteCol) = C;
csd = reshape(Call, [numel(z), sz(2:end)]) * 1e-3;   % A/m^3 -> uA/mm^3
info = struct('method', method, 'cond', opts.Cond, 'condTop', condTop, 'diam', opts.Diam, ...
    'gaussSigma', opts.GaussSigma, 'numOut', opts.NumOut, 'b0', opts.B0, 'b1', opts.B1, ...
    'vaknin', opts.Vaknin, 'surface_mm', surface, 'h_mm', h, 'uniform', uniform, ...
    'units', struct('csd', "uA/mm^3", 'z', "mm below the top channel", 'pots', "V"));
end
