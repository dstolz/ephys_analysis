function test_NumPyArchives()
%test_NumPyArchives  Verification suite for the NumPy archive layer.
%   Checks writeNPY text / shapes, writeNPZ and readNPZ (selected members,
%   zip64 records, a deflated member as numpy.savez_compressed writes it),
%   which exportNWB's staging and kcsdEstimate use. When a Python with
%   NumPy is found (KCSD_PYTHON, else the miniconda base install) the
%   archive is also read by numpy.load; otherwise that check is skipped.
%
%   Usage:  test_NumPyArchives

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('NumPyArchives_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. NumPy archives (writeNPY / writeNPZ / readNPZ) ==\n');
f = fullfile(root, 'a.npz');
A = struct('fs', 1000, 'meta', "{""k"": ""v""}", 'tab', [1 2], 'lab', ["ab" "c" ""], ...
    'P', single([1 2 3; 4 5 6]), 'idx', int64(7), 'none', zeros(0, 2), 'flag', true(1, 3));
info = writeNPZ(f, A, Shapes=struct('fs', "scalar", 'meta', "scalar", 'tab', "full", ...
    'lab', "vector", 'P', "transpose", 'idx', "vector", 'none', "full"));
check(isfile(f) && isequal(info.members, ["fs.npy" "meta.npy" "tab.npy" "lab.npy" "P.npy" "idx.npy" "none.npy" "flag.npy"]), ...
    'writeNPZ writes one .npy member per field, in field order');
R = readNPZ(f);
check(R.fs == 1000 && R.meta == A.meta && isequal(R.tab, [1 2]) && isequal(R.lab, ["ab"; "c"; ""]), ...
    'scalars, a one-row table and text come back');
check(isequal(R.P, A.P.') && isa(R.P, 'single'), 'Shape "transpose" stores DATA.'' as float32');
check(isequal(R.idx, int64(7)) && isequal(size(R.none), [0 2]) && isequal(R.flag, true(3, 1)), ...
    'a one-element vector, an empty [0 x 2] table and bools');
Rm = readNPZ(f, "meta");
check(isequal(fieldnames(Rm), {'meta'}) && Rm.meta == A.meta, 'readNPZ(FILE, VARS) reads only those members');
check(strcmp(errorId(@() readNPZ(f, "nope")), 'readNPZ:NoMember'), 'a member that is not there errors');
f64 = fullfile(root, 'z64.npz');
writeNPZ(f64, A, Shapes=struct('fs', "scalar", 'P', "transpose"), Zip64=true);
R64 = readNPZ(f64);
check(isequal(R64.P, A.P.') && R64.fs == 1000 && isequal(R64.lab, ["ab"; "c"; ""]), 'zip64 records are read back');
check(strcmp(errorId(@() writeNPY(fullfile(root, 'x.npy'), [1 2], Shape="scalar")), 'writeNPY:shape'), ...
    'Shape "scalar" with more than one element errors');
fz = fullfile(root, 'zipped.npz');
tmpNpy = fullfile(root, 'one.npy');
writeNPY(tmpNpy, int32([3 1 2]));
zip(fullfile(root, 'zipped.zip'), 'one.npy', root);   % a deflated member, as numpy.savez_compressed writes
movefile(fullfile(root, 'zipped.zip'), fz);
Rz = readNPZ(fz);
check(isequal(Rz.one, int32([3; 1; 2])), 'a compressed (deflated) member is read');

fprintf('\n== 2. read by NumPy (when available) ==\n');
py = findPython();
if py == ""
    fprintf('  (skipped: no Python with NumPy; set KCSD_PYTHON)\n');
else
    script = fullfile(root, 'check_npz.py');
    fid = fopen(script, 'w');
    fprintf(fid, '%s\n', ...
        "import json, sys", ...
        "import numpy as np", ...
        "d = np.load(sys.argv[1])", ...
        "assert d['fs'].shape == () and d['fs'] == 1000", ...
        "assert json.loads(d['meta'].item()) == {'k': 'v'}", ...
        "assert d['tab'].shape == (1, 2) and list(d['lab']) == ['ab', 'c', '']", ...
        "assert d['P'].shape == (3, 2) and d['P'].dtype == np.float32 and d['P'][2, 1] == 6", ...
        "assert d['idx'].dtype == np.int64 and d['none'].shape == (0, 2) and d['flag'].dtype == np.bool_", ...
        "print('numpy ok')");
    fclose(fid);
    [st, txt] = system(sprintf('"%s" "%s" "%s"', py, script, f));
    check(st == 0 && contains(txt, "numpy ok"), 'numpy.load reads the arrays, shapes, dtypes and text');
    if st ~= 0; fprintf(2, '%s\n', txt); end
end

fprintf('\n######## %d passed, %d failed ########\n', nPass, nFail);
if nFail > 0
    error('test_NumPyArchives:Failures', '%d check(s) failed.', nFail);
end
end


function py = findPython()
%findPython  A Python with NumPy: KCSD_PYTHON, else the miniconda base install ("" for none).
py = "";
candidates = [string(getenv('KCSD_PYTHON')), ...
    string(fullfile(getenv('LOCALAPPDATA'), 'miniconda3', 'python.exe')), ...
    string(fullfile(getenv('USERPROFILE'), 'miniconda3', 'python.exe'))];
for c = candidates(candidates ~= "")
    if ~isfile(c); continue; end
    [st, ~] = system(sprintf('"%s" -c "import numpy"', c));
    if st == 0; py = c; return; end
end
end
