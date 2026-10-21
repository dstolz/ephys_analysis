function test_DatasetFavorites()
%test_DatasetFavorites  Verification suite for the stars kept beside a dataset's outputs (DatasetFavorites).
%   In temporary output folders, no pipeline run: no file (no star, no
%   sort, no unit to star); a round trip of the dataset's and the
%   channels' stars through <Name>_favorites.json (its JSON shape, a new
%   reader seeing them); unit stars recorded with the sort they were set
%   on (a phy folder planted under kilosort4/), a new sort (other spike
%   times) showing none of them while keeping them in the file, the old
%   sort back showing them again; list(); the file removed with the last
%   star; a file that cannot be read (no star, Problem says why, nothing
%   written over it); a read-only folder and a folder gone (nothing
%   changes, DatasetFavorites:CannotWrite); the DatasetOutputs and
%   loadAnalysisSource-struct forms; bad levels and ids; and
%   sessionTable's starred column.
%
%   Usage:  test_DatasetFavorites

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));

root = string(fullfile(tempdir, sprintf('Favorites_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF')))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

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
        id = "";
        try
            fcn();
        catch ME
            id = string(ME.identifier);
        end
    end

fprintf('\n== 1. no file ==\n');
A = fullfile(root, "subjA_day1");
mkdir(A);
fa = DatasetFavorites(A);
check(fa.Name == "subjA_day1" && fa.Folder == A && fa.File == fullfile(A, "subjA_day1_favorites.json") ...
    && ~fa.Dataset && isempty(fa.Channels) && isempty(fa.UnitIds) && isempty(fa.Units) && fa.Problem == "" && isnat(fa.Updated) ...
    && height(fa.list()) == 0 && ~fa.isStarred("dataset") && isequal(fa.isStarred("channel", [1 2]), [false false]), ...
    'no file: nothing starred, no problem; the name is the folder''s');
check(fa.Sort.sort == "" && errorId(@() fa.star("unit", 3)) == "DatasetFavorites:NoSort" && ~isfile(fa.File), ...
    'no sort: a unit cannot be starred, and nothing is written');

fprintf('\n== 2. the dataset and its channels, round trip ==\n');
fa.star("dataset");
fa.star("channel", [5 3]);
fa.star("channel", 5);   % again: kept once
J = jsondecode(fileread(fa.File));
check(isfile(fa.File) && J.schema == "ephys-favorites/1" && J.dataset == "subjA_day1" && J.starred == true ...
    && isequal(J.channels(:).', [3 5]) && isempty(J.units) && ~isnat(fa.Updated) && string(J.updated) ~= "", ...
    'the file: schema, dataset name, starred, channels ascending, no units, when');
fb = DatasetFavorites(A);
check(fb.Dataset && isequal(fb.Channels, [3 5]) && isequal(fb.isStarred("channel", [3 4 5]), [true false true]) ...
    && isequal(fb.list().label, ["dataset"; "channel 3"; "channel 5"]) && abs(seconds(fb.Updated - fa.Updated)) < 1, ...
    'a new reader sees the same stars; list() names them');
fb.star("channel", 3, false);
fc = DatasetFavorites(A);
check(isequal(fc.Channels, 5), 'unstarring a channel is written at once');

fprintf('\n== 3. units and their sort ==\n');
ks = fullfile(A, "kilosort4");
mkdir(ks);
writeBytes(fullfile(ks, "params.py"), uint8('dat_path = ''x.bin'''));
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 800, 'uint8'));
fu = DatasetFavorites(A);
check(fu.Sort.sort == "kilosort4" && fu.Sort.spikeTimesBytes == 800 && isempty(fu.UnitIds), ...
    'the sort in use: its folder relative to the output folder and the size of its spike times');
fu.star("unit", [0 12]);
J = jsondecode(fileread(fu.File));
check(isequal(fu.UnitIds, [0 12]) && isequal(fu.isStarred("unit", [0 12 13]), [true true false]) && isscalar(J.units) ...
    && J.units.sort == "kilosort4" && J.units.spikeTimesBytes == 800 && isequal(J.units.ids(:).', [0 12]) && J.starred, ...
    'units 0 and 12 starred with their sort; cluster id 0 is a unit too; the dataset''s star kept');
Tob = table(["unit"; "unit"; "channel"; "dataset"; ""], [0; 12; NaN; NaN; NaN], [5; 6; 5; NaN; NaN], ...
    'VariableNames', {'kind', 'unitId', 'channel'});   % figureObservations' rows (kind "": none, as perSession's)
check(isequal(fu.observationStarred(Tob, "units"), [true; true; true; true; false]) ...
    && isequal(fu.observationStarred(Tob, "detected"), [true; false; true; true; false]) && isempty(fu.observationStarred(Tob([], :), "units")), ...
    'observationStarred: a sorted unit by its id, a detection channel and a channel by their channel, the dataset by its star');
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 1600, 'uint8'));   % sorted again into the same folder
fr = DatasetFavorites(A);
check(isempty(fr.UnitIds) && ~any(fr.isStarred("unit", [0 12])) && isscalar(fr.Units) && height(fr.list()) == 2, ...
    'a new sort (other spike times) shows none of the old sort''s stars, which stay in the file');
fr.star("unit", 7);
J = jsondecode(fileread(fr.File));
check(isequal(fr.UnitIds, 7) && numel(J.units) == 2, 'a star on the new sort is kept beside the old sort''s');
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 800, 'uint8'));   % the old sort back (e.g. restored)
fo = DatasetFavorites(A);
check(isequal(fo.UnitIds, [0 12]) && ~fo.isStarred("unit", 7), 'the old sort back: its own stars again');
fo.star("unit", [0 12], false);
check(isscalar(fo.Units) && fo.Units.spikeTimesBytes == 1600, 'a sort left without stars is dropped from the file');

fprintf('\n== 4. the last star removes the file ==\n');
B = fullfile(root, "subjB_day1");
mkdir(B);
fB = DatasetFavorites(B);
fB.star("dataset");
had = isfile(fB.File);
fB.star("dataset", [], false);
check(had && ~isfile(fB.File) && isnat(fB.Updated), 'unstarring the only star deletes the file');

fprintf('\n== 5. a file that cannot be read ==\n');
writeBytes(fB.File, uint8('{not json'));
fx = DatasetFavorites(B);
check(~fx.Dataset && fx.Problem ~= "" && contains(fx.Problem, "subjB_day1_favorites.json"), ...
    sprintf('an unreadable file: no star, Problem says why ("%s")', fx.Problem));
check(errorId(@() fx.star("dataset")) == "DatasetFavorites:Unreadable" && string(fileread(fB.File)) == "{not json" && ~fx.Dataset, ...
    'nothing is written over it');
writeBytes(fB.File, uint8('{"schema": "other/1"}'));
check(DatasetFavorites(B).Problem ~= "", 'a JSON file of another schema is not read either');
delete(fB.File);

fprintf('\n== 6. a folder that cannot be written ==\n');
C = fullfile(root, "subjC_day1");
mkdir(C);
fC = DatasetFavorites(C);
if ispc
    me = string(getenv('USERNAME'));
    [st, out] = system(sprintf('icacls "%s" /deny "%s":(W)', C, me));
    undeny = onCleanup(@() system(sprintf('icacls "%s" /remove:d "%s"', C, me)));
else
    [st, out] = system(sprintf('chmod a-w "%s"', C));
    undeny = onCleanup(@() system(sprintf('chmod u+w "%s"', C)));
end
if st == 0
    e = errorId(@() fC.star("channel", 4));
    check(e == "DatasetFavorites:CannotWrite" && isempty(fC.Channels) && ~isfile(fC.File) && isempty(dir(fullfile(C, "*.partial"))), ...
        'a read-only folder: DatasetFavorites:CannotWrite, nothing changes, no partial file left');
    try
        fC.star("channel", 4);
    catch ME
        check(contains(ME.message, "read-only") && contains(ME.message, "subjC_day1"), ...
            sprintf('its message names the dataset and says read-only ("%s")', ME.message));
    end
else
    fprintf('  (skipped: the folder could not be made read-only: %s)\n', strtrim(out));
end
clear undeny
D = fullfile(root, "subjD_day1");
mkdir(D);
fD = DatasetFavorites(D);
rmdir(D);
check(errorId(@() fD.star("dataset")) == "DatasetFavorites:CannotWrite" && ~fD.Dataset, ...
    'an output folder gone: DatasetFavorites:CannotWrite, the star stays off');
check(errorId(@() DatasetFavorites(D)) == "DatasetFavorites:NoFolder", 'reading a folder that is not there is an error');

fprintf('\n== 7. from a DatasetOutputs and a loadAnalysisSource struct ==\n');
out = DatasetOutputs(A);
f1 = DatasetFavorites(out);
f2 = DatasetFavorites(struct('outputs', out, 'folder', A, 'name', "subjA_day1"));
check(f1.File == fa.File && f2.File == fa.File && f1.Dataset && isequal(f1.Channels, 5) && f1.Sort.sort == "kilosort4" ...
    && isequal(f2.Channels, 5), 'the same file and stars from a DatasetOutputs and from a source struct');
f3 = DatasetFavorites(A, Name="other_name");
check(f3.File == fullfile(A, "other_name_favorites.json") && ~f3.Dataset, 'Name= picks the file of another dataset name');
check(errorId(@() DatasetFavorites(42)) == "DatasetFavorites:BadTarget" ...
    && errorId(@() fa.star("probe", 1)) == "DatasetFavorites:BadLevel" ...
    && errorId(@() fa.star("channel", 0)) == "DatasetFavorites:BadId" && errorId(@() fa.star("unit", -1)) == "DatasetFavorites:BadId" ...
    && errorId(@() fa.star("channel", 2.5)) == "DatasetFavorites:BadId", ...
    'a bad target, level or id is an error');

fprintf('\n== 8. sessionTable''s starred column ==\n');
S = sessionTable(["subjA_day1"; "subjB_day1"; "x"], ["a"; "b"; "x"], Folders=[A; B; ""]);
S0 = sessionTable(["subjA_day1"; "subjB_day1"], ["a"; "b"]);
check(isequal(S.starred, [true; false; false]) && ~any(S0.starred), ...
    'sessionTable: starred from each folder''s favorites file, false without a folder');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DatasetFavorites:Failures', '%d checks failed.', nFail);
end
end


function writeBytes(file, bytes)
fid = fopen(file, 'w');
fwrite(fid, bytes, 'uint8');
fclose(fid);
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
