function [csd, G, info] = kcsdEstimate(posMm, pots, opts)
%kcsdEstimate  Kernel current source density of laminar (or planar) potentials with kCSD-python.
%   [CSD, G] = kcsdEstimate(POS, POTS) estimates the CSD from POTS, [nChan x
%   nTime] potentials in V (or [nChan x nTime x nGroups]: every page at
%   once), recorded at POS, [nChan x 1] depths in mm (KCSD1D: a laminar
%   column, epochMatrixCSD's depth_mm) or [nChan x 2] (x, depth) positions
%   in mm (KCSD2D: a shank's whole layout, pos_mm with Columns="2d"), with
%   kCSD-python (Potworowski, Jakuczun, Łęski & Wójcik 2012, Neural Comput
%   24:541; https://github.com/Neuroinflab/kCSD-python). The estimator runs
%   in a Python with kcsd (kcsd_estimate.py beside this file, through
%   system; nothing needs MATLAB's pyenv): the arrays go out and come back
%   in .npz files (writeNPZ, readNPZ).
%
%   CSD is the estimate on kCSD's grid in uA/mm^3 (kCSD's own unit for mm,
%   mV and S/m), positive = source: [nX x nTime (x nGroups)] for depths,
%   [nX x nY x nTime (x nGroups)] for positions. G has the grid: x (mm, a
%   column; depth below the top channel for a laminar column) and, in 2-D,
%   y. INFO has lambd and R (as used, after a cross-validation), nSources,
%   potEst [nChan x nTime (x nGroups)] V (the potentials the estimate
%   reproduces at the channels), cv (lambdas, Rs, errors [nRs x nLambdas],
%   when cross-validated), params (the keyword arguments passed), python,
%   seconds.
%
%   Options (kCSD's keyword arguments, in its units: mm, S/m)
%     Sigma        tissue conductivity, S/m (0.3)
%     H            thickness of the slice / column the sources fill, mm
%                  (kCSD's 1)
%     NSources     basis sources requested (kCSD's default, 1000)
%     RInit        basis width R, mm (kCSD's 0.23); cross-validate Rs to
%                  pick one for the channel spacing
%     Gdx, Gdy     grid steps, mm (kCSD's 1% of the span)
%     ExtX, ExtY   how far the estimate extends past the channels, mm (0)
%     XMin, XMax, YMin, YMax   the grid's bounds, mm (the channels' span)
%     Lambda       ridge (0): overridden by a cross-validation
%     SrcType      "gauss" (default) | "step" | "gauss_lim"
%     Lambdas, Rs  cross-validate over them (leave-one-electrode-out,
%                  k.cross_validate) and use the best: either alone takes
%                  kCSD's default for the other (lambdas 1e-2 .. 1e-25 and
%                  0; R = RInit)
%     CrossValidate  true: cross-validate with kCSD's defaults when no
%                  Lambdas or Rs are given (false)
%     LCurve       true: pick lambda and R by kCSD's L-curve instead
%                  (k.L_curve, over Lambdas / Rs or its defaults)
%     Python       the python.exe to run ("" = KCSD_PYTHON, then MATLAB's
%                  pyenv Executable, a miniconda3 base install, then python
%                  on the PATH: the first that imports numpy, scipy and
%                  kcsd; remembered for the session)
%     Source       a folder to import kcsd from (a kCSD-python checkout)
%                  when it is not installed in that Python
%     Verbose      true: print kCSD's output (false)
%
%   Errors: kcsdEstimate:Size, kcsdEstimate:Dim (POS has more than two
%   columns), kcsdEstimate:NoPython (no Python imports kcsd),
%   kcsdEstimate:Python (the estimator failed; its output is in the
%   message).
%
%   See also epochMatrixCSD, sessionDataCSD, icsdEstimate, laminarColumns,
%   KCSDExport, EphysDataset.exportKCSD.

arguments
    posMm (:,:) double {mustBeFinite}
    pots {mustBeNumeric}
    opts.Sigma (1,1) double {mustBePositive} = 0.3
    opts.H double = []
    opts.NSources double = []
    opts.RInit double = []
    opts.Gdx double = []
    opts.Gdy double = []
    opts.ExtX double = []
    opts.ExtY double = []
    opts.XMin double = []
    opts.XMax double = []
    opts.YMin double = []
    opts.YMax double = []
    opts.Lambda double = []
    opts.SrcType (1,1) string {mustBeMember(opts.SrcType, ["gauss" "step" "gauss_lim"])} = "gauss"
    opts.Lambdas double = []
    opts.Rs double = []
    opts.CrossValidate (1,1) logical = false
    opts.LCurve (1,1) logical = false
    opts.Python (1,1) string = ""
    opts.Source (1,1) string = ""
    opts.Verbose (1,1) logical = false
end
t0 = tic;
if isvector(posMm); posMm = posMm(:); end
[nChan, dim] = size(posMm);
if dim > 2
    error('kcsdEstimate:Dim', 'POS must have one column (depths) or two (x, depth), not %d.', dim);
end
sz = size(pots);
if sz(1) ~= nChan
    error('kcsdEstimate:Size', 'POTS has %d rows for %d positions.', sz(1), nChan);
end
py = kcsdPython(opts.Python, opts.Source);

% the estimator's keyword arguments (kCSD's names), only those given
params = struct('sigma', opts.Sigma, 'src_type', opts.SrcType);
names = struct('H', "h", 'NSources', "n_src_init", 'RInit', "R_init", 'Gdx', "gdx", 'Gdy', "gdy", ...
    'ExtX', "ext_x", 'ExtY', "ext_y", 'XMin', "xmin", 'XMax', "xmax", 'YMin', "ymin", 'YMax', "ymax", ...
    'Lambda', "lambd");
for f = string(fieldnames(names)).'
    if ~isempty(opts.(f)); params.(names.(f)) = opts.(f); end
end
if dim == 1
    for f = ["gdy" "ext_y" "ymin" "ymax"]
        if isfield(params, f); params = rmfield(params, f); end
    end
end
cv = ~isempty(opts.Lambdas) || ~isempty(opts.Rs) || opts.CrossValidate || opts.LCurve;
if ~isempty(opts.Lambdas); params.cv_lambdas = reshape(opts.Lambdas, 1, []); end
if ~isempty(opts.Rs); params.cv_Rs = reshape(opts.Rs, 1, []); end
if opts.LCurve; params.l_curve = true; elseif cv && isempty(opts.Lambdas) && isempty(opts.Rs); params.cv_lambdas = []; end
if opts.Source ~= ""; params.source_path = strrep(opts.Source, '\', '/'); end

% in and out through .npz files in a temporary folder
folder = tempname;
mkdir(folder);
cleaner = onCleanup(@() rmdir(folder, 's'));
inFile = fullfile(folder, 'in.npz');
outFile = fullfile(folder, 'out.npz');
Y = double(reshape(pots, nChan, []));                     % every page at once
finiteCol = all(isfinite(Y), 1);                           % a group without epochs is all NaN: left NaN
if ~any(finiteCol)
    error('kcsdEstimate:NoData', 'POTS holds no finite column (every group without epochs?).');
end
A = struct();
A.ele_pos = posMm;
A.pots = Y(:, finiteCol) * 1e3;                           % V -> mV
A.params = string(jsonencode(params));
writeNPZ(inFile, A, Shapes=struct('ele_pos', "full", 'pots', "full", 'params', "scalar"));

script = fullfile(fileparts(mfilename('fullpath')), 'kcsd_estimate.py');
[status, txt] = system(sprintf('"%s" "%s" "%s" "%s"', py, script, inFile, outFile));
if opts.Verbose; fprintf('%s\n', strtrim(txt)); end
if status ~= 0 || ~contains(txt, "KCSD_OK") || ~isfile(outFile)
    error('kcsdEstimate:Python', 'kCSD-python failed (exit %d) in %s:\n%s', status, py, strtrim(txt));
end
out = readNPZ(outFile);

G = struct('x', double(out.estm_x(:)));
nGrid = numel(G.x);
if dim == 2
    G.y = double(out.estm_y(:));
    nGrid = nGrid * numel(G.y);
end
C = NaN(nGrid, size(Y, 2));
C(:, finiteCol) = reshape(double(out.csd), nGrid, []);
potEst = NaN(nChan, size(Y, 2));
potEst(:, finiteCol) = reshape(double(out.pot_est), nChan, []) / 1e3;
if dim == 1
    csd = reshape(C, [numel(G.x), sz(2:end)]);
else
    csd = reshape(C, [numel(G.x), numel(G.y), sz(2:end)]);
end
info = struct('lambd', double(out.lambd), 'R', double(out.R), 'nSources', double(out.n_src), ...
    'potEst', reshape(potEst, sz), 'cv', [], 'params', params, ...
    'python', py, 'seconds', toc(t0), ...
    'units', struct('csd', "uA/mm^3", 'x', "mm", 'y', "mm", 'pots', "V"));
if cv
    info.cv = struct('lambdas', double(out.cv_lambdas(:)), 'Rs', double(out.cv_Rs(:)), ...
        'errors', reshape(double(out.cv_errors), numel(out.cv_Rs), numel(out.cv_lambdas)), ...
        'criterion', ternary(opts.LCurve, "L-curve (larger is better)", "leave-one-out error (smaller is better)"));
end
end


function py = kcsdPython(given, source)
%kcsdPython  The first Python that imports numpy, scipy and kcsd (cached per session).
persistent found
if given ~= ""
    candidates = given;
elseif ~isempty(found) && isfile(found)
    py = found;
    return
else
    candidates = string(getenv('KCSD_PYTHON'));
    try
        pe = pyenv;
        candidates(end + 1) = string(pe.Executable);
    catch
    end
    candidates = [candidates, ...
        string(fullfile(getenv('LOCALAPPDATA'), 'miniconda3', 'python.exe')), ...
        string(fullfile(getenv('USERPROFILE'), 'miniconda3', 'python.exe')), ...
        string(fullfile(getenv('LOCALAPPDATA'), 'anaconda3', 'python.exe')), ...
        string(fullfile(getenv('USERPROFILE'), 'anaconda3', 'python.exe')), ...
        "python", "python3"];
end
candidates = unique(candidates(candidates ~= "" & ~ismissing(candidates)), 'stable');
probe = "import numpy, scipy.integrate as si; si.simps = getattr(si, 'simps', si.simpson); import kcsd";
if source ~= ""
    probe = sprintf("import sys; sys.path.insert(0, '%s'); ", strrep(source, '\', '/')) + probe;
end
tried = strings(0, 1);
for c = candidates
    if contains(c, filesep) && ~isfile(c); continue; end
    [st, out] = system(sprintf('"%s" -c "%s"', c, probe));
    if st == 0
        py = c;
        if given == ""; found = c; end
        return
    end
    tried(end + 1) = c + ": " + firstLine(out); %#ok<AGROW>
end
error('kcsdEstimate:NoPython', ...
    ['No Python imports numpy, scipy and kcsd. Pass Python= (and Source= for a kCSD-python checkout), or set ' ...
     'KCSD_PYTHON; pip install kcsd (or pip install -e <kCSD-python>) in that environment.%s'], ...
    ternary(isempty(tried), "", sprintf('\nTried:\n  %s', strjoin(tried, newline + "  "))));
end


function s = firstLine(txt)
lines = splitlines(strtrim(string(txt)));
lines = lines(lines ~= "");
if isempty(lines); s = "(no output)"; else; s = lines(end); end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
