function test_DatasetNotes()
%test_DatasetNotes  Verification suite for the notes kept beside a dataset's outputs (DatasetNotes), the notepad (NotePad) and the search window (NoteSearch).
%   In temporary output folders, no pipeline run: no file (no note, no
%   sort, no unit note); a round trip of the dataset's and the channels'
%   notes through <Name>_notes.json (its JSON shape, line breaks kept, ends
%   trimmed, the same text writing nothing, blank text removing a note);
%   unit notes recorded with the sort they were written on (a phy folder
%   planted under kilosort4/), a new sort showing none of them while keeping
%   them in the file (list(AllSorts=true) shows them as of another sort),
%   the old sort back showing them again; the file removed with the last
%   note; a file that cannot be read (no note, Problem says why, nothing
%   written over it); a read-only folder and a folder gone (nothing changes,
%   DatasetNotes:CannotWrite); the three kinds of target; bad levels and
%   ids. Then the notepad, hidden: its text written on save and before
%   another note opens in it, SavedFcn, blank text removing the note, a
%   note that cannot be written staying in the box (open refused, the
%   first close refused), a file that cannot be read not editable. Then
%   the search window, hidden: every word in any case over the dataset
%   name, item and text, the count, the snippet, the pick shown in full,
%   Go to and Edit note (off for another sort's note), new entries keeping
%   the search and the pick.
%
%   Usage:  test_DatasetNotes

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));

root = string(fullfile(tempdir, sprintf('Notes_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF')))); %#ok<TNOW1,DATST>
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
na = DatasetNotes(A);
[t0, w0] = na.note("dataset");
check(na.Name == "subjA_day1" && na.Folder == A && na.File == fullfile(A, "subjA_day1_notes.json") ...
    && isempty(na.Notes) && na.Problem == "" && isnat(na.Updated) && height(na.list()) == 0 && t0 == "" && isnat(w0) ...
    && ~na.hasNote("dataset") && isequal(na.hasNote("channel", [1 2]), [false false]) && na.note("unit", 3) == "", ...
    'no file: no note, no problem; the name is the folder''s');
check(na.Sort.sort == "" && errorId(@() na.setNote("unit", 3, "x")) == "DatasetNotes:NoSort" && ~isfile(na.File), ...
    'no sort: a unit cannot have a note, and nothing is written');
na.setNote("channel", 4, "   ");
check(~isfile(na.File), 'blank text on no note writes nothing');

fprintf('\n== 2. the dataset and its channels, round trip ==\n');
na.setNote("dataset", [], sprintf('  good session\r\nreward line flaky  \n\n'));
na.setNote("channel", 5, "noisy after 20 min");
na.setNote("channel", 3, "dead");
J = jsondecode(fileread(na.File));
check(isfile(na.File) && J.schema == "ephys-notes/1" && J.dataset == "subjA_day1" ...
    && J.note.text == "good session" + newline + "reward line flaky" && string(J.note.updated) ~= "" ...
    && isequal([J.channels.id], [3 5]) && string(J.channels(2).text) == "noisy after 20 min" && isempty(J.units) ...
    && ~isnat(na.Updated) && string(J.updated) ~= "", ...
    'the file: schema, dataset name, the dataset''s note (line breaks kept as LF, ends trimmed), channels ascending, no units, when');
nb = DatasetNotes(A);
L = nb.list();
check(nb.note("dataset") == na.note("dataset") && nb.note("channel", 5) == "noisy after 20 min" ...
    && isequal(nb.hasNote("channel", [3 4 5]), [true false true]) && nb.hasNote("dataset") ...
    && isequal(L.label, ["dataset"; "channel 3"; "channel 5"]) && all(L.current) && all(~isnat(L.updated)) ...
    && abs(seconds(nb.Updated - na.Updated)) < 1, ...
    'a new reader sees the same notes; list() names them, dataset first, channels ascending');
stamp0 = nb.Updated;
bytes0 = fileread(nb.File);
pause(1.1);
nb.setNote("channel", 5, "noisy after 20 min" + newline);
check(strcmp(fileread(nb.File), bytes0) && nb.Updated == stamp0, 'the same text (but for trailing space) writes nothing');
nb.setNote("channel", 3, "");
nc = DatasetNotes(A);
check(~nc.hasNote("channel", 3) && nc.hasNote("channel", 5) && height(nc.list()) == 2, 'blank text removes a channel''s note, at once');
[~, w5] = nc.note("channel", 5);
nc.setNote("channel", 5, "noisy after 25 min");
[t5, w5b] = DatasetNotes(A).note("channel", 5);
check(t5 == "noisy after 25 min" && w5b > w5, 'a changed note gets a new time');

fprintf('\n== 3. units and their sort ==\n');
ks = fullfile(A, "kilosort4");
mkdir(ks);
writeBytes(fullfile(ks, "params.py"), uint8('dat_path = ''x.bin'''));
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 800, 'uint8'));
nu = DatasetNotes(A);
check(nu.Sort.sort == "kilosort4" && nu.Sort.spikeTimesBytes == 800 && ~any(nu.hasNote("unit", [0 12])), ...
    'the sort in use: its folder relative to the output folder and the size of its spike times');
nu.setNote("unit", 12, "bursty");
nu.setNote("unit", 0, "unit 0 is a unit too");
J = jsondecode(fileread(nu.File));
check(isscalar(J.units) && J.units.sort == "kilosort4" && J.units.spikeTimesBytes == 800 ...
    && isequal([J.units.notes.id], [0 12]) && string(J.units.notes(2).text) == "bursty" && isfield(J, 'note') ...
    && isequal(nu.hasNote("unit", [0 12 13]), [true true false]) && nu.note("unit", 12) == "bursty", ...
    'unit notes kept with their sort, ids ascending; cluster id 0 is a unit too; the dataset''s note kept');
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 1600, 'uint8'));   % sorted again into the same folder
nr = DatasetNotes(A);
La = nr.list(AllSorts=true);
check(~any(nr.hasNote("unit", [0 12])) && nr.note("unit", 12) == "" && height(nr.list()) == 2 && height(La) == 4 ...
    && isequal(La.current, [true; true; false; false]) && La.label(4) == "unit 12 (another sort)" && La.text(4) == "bursty", ...
    'a new sort (other spike times) shows none of the old sort''s notes; list(AllSorts=true) shows them as of another sort');
nr.setNote("unit", 7, "new sort's unit");
J = jsondecode(fileread(nr.File));
check(nr.note("unit", 7) == "new sort's unit" && numel(J.units) == 2, 'a note on the new sort is kept beside the old sort''s');
writeBytes(fullfile(ks, "spike_times.npy"), zeros(1, 800, 'uint8'));   % the old sort back (e.g. restored)
no = DatasetNotes(A);
check(no.note("unit", 12) == "bursty" && ~no.hasNote("unit", 7), 'the old sort back: its own notes again');
fav = DatasetFavorites(A);
check(isequal(fav.Sort, no.Sort), 'a star and a note record the same sort (sortIdentity)');
no.setNote("unit", 0, "");
no.setNote("unit", 12, "");
J = jsondecode(fileread(no.File));
check(isscalar(J.units) && J.units.spikeTimesBytes == 1600, 'a sort left without notes is dropped from the file');

fprintf('\n== 4. the last note removes the file ==\n');
B = fullfile(root, "subjB_day1");
mkdir(B);
nB = DatasetNotes(B);
nB.setNote("dataset", NaN, "only note");
had = isfile(nB.File);
nB.setNote("dataset", NaN, "");
check(had && ~isfile(nB.File) && isnat(nB.Updated), 'removing the only note deletes the file');

fprintf('\n== 5. a file that cannot be read ==\n');
writeBytes(nB.File, uint8('{not json'));
nx = DatasetNotes(B);
check(isempty(nx.Notes) && nx.Problem ~= "" && contains(nx.Problem, "subjB_day1_notes.json"), ...
    sprintf('an unreadable file: no note, Problem says why ("%s")', nx.Problem));
check(errorId(@() nx.setNote("dataset", [], "x")) == "DatasetNotes:Unreadable" && string(fileread(nB.File)) == "{not json", ...
    'nothing is written over it');
writeBytes(nB.File, uint8('{"schema": "ephys-favorites/1"}'));
check(DatasetNotes(B).Problem ~= "", 'a JSON file of another schema is not read either');
delete(nB.File);

fprintf('\n== 6. a folder that cannot be written ==\n');
C = fullfile(root, "subjC_day1");
mkdir(C);
nC = DatasetNotes(C);
[st, out, undeny] = denyWrite(C); %#ok<ASGLU> undeny gives the folder back when cleared
if st == 0
    e = errorId(@() nC.setNote("channel", 4, "x"));
    check(e == "DatasetNotes:CannotWrite" && ~nC.hasNote("channel", 4) && ~isfile(nC.File), ...
        'a read-only folder: DatasetNotes:CannotWrite, nothing changes');
    try
        nC.setNote("channel", 4, "x");
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
nD = DatasetNotes(D);
rmdir(D);
check(errorId(@() nD.setNote("dataset", [], "x")) == "DatasetNotes:CannotWrite" && ~nD.hasNote("dataset"), ...
    'an output folder gone: DatasetNotes:CannotWrite, no note');
check(errorId(@() DatasetNotes(D)) == "DatasetNotes:NoFolder", 'reading a folder that is not there is an error');

fprintf('\n== 7. from a DatasetOutputs and a loadAnalysisSource struct; bad input ==\n');
out = DatasetOutputs(A);
n1 = DatasetNotes(out);
n2 = DatasetNotes(struct('outputs', out, 'folder', A, 'name', "subjA_day1"));
check(n1.File == na.File && n2.File == na.File && n1.hasNote("dataset") && n1.Sort.sort == "kilosort4" ...
    && n2.note("channel", 5) == "noisy after 25 min", 'the same file and notes from a DatasetOutputs and from a source struct');
n3 = DatasetNotes(A, Name="other_name");
check(n3.File == fullfile(A, "other_name_notes.json") && isempty(n3.Notes), 'Name= picks the file of another dataset name');
check(errorId(@() DatasetNotes(42)) == "DatasetNotes:BadTarget" ...
    && errorId(@() na.setNote("probe", 1, "x")) == "DatasetNotes:BadLevel" ...
    && errorId(@() na.setNote("channel", 0, "x")) == "DatasetNotes:BadId" && errorId(@() na.setNote("unit", -1, "x")) == "DatasetNotes:BadId" ...
    && errorId(@() na.setNote("channel", 2.5, "x")) == "DatasetNotes:BadId" && errorId(@() na.setNote("channel", [1 2], "x")) == "DatasetNotes:BadId", ...
    'a bad target, level or id is an error');

fprintf('\n== 8. the notepad ==\n');
E = fullfile(root, "subjE_day1");
mkdir(E);
nE = DatasetNotes(E);
saved = strings(0, 1);
item = @(level, id, title) struct('notes', nE, 'level', level, 'id', id, 'title', title);
p = NotePad(item("dataset", NaN, "subjE_day1"), Visible=false, SavedFcn=@(it) onSaved(it));
check(p.Text == "" && ~p.Dirty && p.Area.Editable == "on" && contains(p.StateLabel.Text, "No note yet") ...
    && contains(p.StateLabel.Text, "subjE_day1_notes.json") && string(p.Fig.Name) == "Note: subjE_day1" && p.TitleLabel.Text == "subjE_day1", ...
    'opened on a dataset with no note: an empty box, the title, where it will be kept');
p.setText(["first line"; "second line"]);
check(p.Dirty && contains(p.StateLabel.Text, "Typing") && ~isfile(nE.File), 'typed: not written yet');
ok = p.save();
check(ok && ~p.Dirty && nE.note("dataset") == "first line" + newline + "second line" && isfile(nE.File) ...
    && startsWith(p.StateLabel.Text, "Written ") && isequal(saved, "subjE_day1"), ...
    'Save writes the note (its lines joined), says when, and calls SavedFcn');
p.setText("channel 9 is dead");
p.open(item("channel", 9, "subjE_day1 · channel 9"));
check(nE.note("dataset") == "channel 9 is dead" && p.Item.level == "channel" && p.Item.id == 9 && p.Text == "" ...
    && ~p.Dirty && string(p.Fig.Name) == "Note: subjE_day1 · channel 9", ...
    'opening another note writes the text in the box first, then shows the new (empty) one');
nSaved = numel(saved);
ok = p.open(item("channel", 9, "subjE_day1 · channel 9"));
check(ok && numel(saved) == nSaved, 'opening the note it shows does nothing');
p.setText("  ");
p.save();
p.open(item("dataset", NaN, "subjE_day1"));
check(~nE.hasNote("channel", 9) && p.Text == "channel 9 is dead", 'blank text is no note; reopened, the dataset''s note is in the box');
p.setText("written on close");
p.close();
check(~isvalid(p) && nE.note("dataset") == "written on close", 'closing writes the text in the box');
F = fullfile(root, "subjF_day1");
mkdir(F);
nF = DatasetNotes(F);
q = NotePad(struct('notes', nF, 'level', "dataset", 'id', NaN, 'title', "subjF_day1"), Visible=false);
[st, out, undeny] = denyWrite(F); %#ok<ASGLU> undeny gives the folder back when cleared
if st == 0
    q.setText("cannot be written");
    okSave = q.save();
    okOpen = q.open(struct('notes', nF, 'level', "channel", 'id', 2, 'title', "subjF_day1 · channel 2"));
    check(~okSave && ~okOpen && q.Dirty && q.Item.level == "dataset" && q.Text == "cannot be written" ...
        && startsWith(q.StateLabel.Text, "Not written") && ~isfile(nF.File), ...
        sprintf('a read-only folder: the text stays in the box, the line under it says why, open is refused ("%s")', q.StateLabel.Text));
    q.close();
    stillOpen = isvalid(q) && contains(q.StateLabel.Text, "Close again");
    q.close();
    check(stillOpen && ~isvalid(q), 'the first close is refused, saying so; the second discards the text');
else
    fprintf('  (skipped: the folder could not be made read-only: %s)\n', strtrim(out));
    delete(q);
end
clear undeny
writeBytes(nB.File, uint8('{not json'));
nx = DatasetNotes(B);
r = NotePad(struct('notes', nx, 'level', "dataset", 'id', NaN, 'title', "subjB_day1"), Visible=false);
check(r.Area.Editable == "off" && r.SaveButton.Enable == "off" && startsWith(r.StateLabel.Text, "Cannot be edited"), ...
    'a notes file that cannot be read: the box cannot be edited, the line under it says why');
delete(r);
delete(nB.File);

fprintf('\n== 9. the search window ==\n');
nA = DatasetNotes(A);   % the dataset, channel 5, unit 7 of another sort (spike times of 800 bytes are back)
nE.reload();            % its dataset's note
LA = nA.list(AllSorts=true);
LE = nE.list(AllSorts=true);
entries = [[table(ones(height(LA), 1), repmat("subjA_day1", height(LA), 1), 'VariableNames', ["dataset" "name"]) LA]; ...
    [table(2 * ones(height(LE), 1), repmat("subjE_day1", height(LE), 1), 'VariableNames', ["dataset" "name"]) LE]];
went = [];
edited = [];
s = NoteSearch(entries, Visible=false, GoToFcn=@(e) onGoTo(e), EditFcn=@(e) onEdit(e), EmptyText="none here");
n = height(entries);
check(numel(s.Matches) == n && height(s.Table.Data) == n && s.CountLabel.Text == n + " notes" && s.Picked == 0 ...
    && s.GoToButton.Enable == "off" && isequal(string(s.Table.Data.Properties.VariableNames), ["Dataset" "Item" "Note" "Updated"]), ...
    sprintf('every note listed, nothing picked (%d notes)', n));
s.search("REWARD flaky");
check(isscalar(s.Matches) && s.Table.Data.Item(1) == "dataset" && s.Table.Data.Dataset(1) == "subjA_day1" ...
    && s.Table.Data.Note(1) == "reward line flaky ..." && contains(s.CountLabel.Text, "1 of " + n), ...
    'every word, in any case, in the note''s text; the Note column shows the line holding the first word (" ...": more lines)');
s.search("subjE");
check(isscalar(s.Matches) && s.Table.Data.Dataset(1) == "subjE_day1", 'a word of the dataset name');
s.search("unit 7");
check(isscalar(s.Matches) && s.Table.Data.Item(1) == "unit 7 (another sort)", 'words of what the note is on');
s.pick(1);
check(s.Preview.Value == "new sort's unit" && s.GoToButton.Enable == "on" && s.EditButton.Enable == "off", ...
    'a note on another sort, picked: shown in full; Go to on, Edit note off');
s.edit();
s.goTo();
check(isempty(edited) && istable(went) && went.dataset == 1 && went.level == "unit" && went.id == 7 && ~went.current, ...
    'Go to hands its entry to GoToFcn; Edit note does nothing for it');
s.search("noisy");
s.pick(1);
s.edit();
check(istable(edited) && edited.level == "channel" && edited.id == 5 && s.EditButton.Enable == "on", 'Edit note hands a note in use to EditFcn');
s.setEntries(entries(entries.dataset == 1, :));
check(s.Query == "noisy" && isscalar(s.Matches) && s.Picked == 1, ...
    'new entries keep the search and the pick');
s.search("no such words");
check(isempty(s.Matches) && contains(s.CountLabel.Text, "0 of") && s.Preview.Value == "", 'nothing matches: an empty list');
s.setEntries(entries([], :));
check(s.CountLabel.Text == "none here", 'no notes at all: the window says EmptyText');
s.close();
check(~isvalid(s), 'closed');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DatasetNotes:Failures', '%d checks failed.', nFail);
end

    function onSaved(it)
        saved(end+1, 1) = it.title;
    end
    function onGoTo(e)
        went = e;
    end
    function onEdit(e)
        edited = e;
    end
end


function [st, out, undeny] = denyWrite(folder)
%denyWrite  Make FOLDER read-only for this user; UNDENY gives it back when cleared.
if ispc
    me = string(getenv('USERNAME'));
    [st, out] = system(sprintf('icacls "%s" /deny "%s":(W)', folder, me));
    undeny = onCleanup(@() system(sprintf('icacls "%s" /remove:d "%s"', folder, me)));
else
    [st, out] = system(sprintf('chmod a-w "%s"', folder));
    undeny = onCleanup(@() system(sprintf('chmod u+w "%s"', folder)));
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
