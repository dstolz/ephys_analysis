function restoreAppPrefs(backupFile)
%restoreAppPrefs  Put back EphysPreprocessingApp preferences from a backup .mat.
%   restoreAppPrefs(BACKUPFILE) replaces the whole preference group
%   'EphysPreprocessingApp' with the struct saved in BACKUPFILE (variable
%   'saved', as wikiScreenshots writes it to OUTFOLDER/prefs_backup.mat).
%   For when a wikiScreenshots run had to be killed before it could restore
%   them itself. Check first that no other app-driving MATLAB is running.
%
%   See also wikiScreenshots.

arguments
    backupFile (1,1) string {mustBeFile}
end
S = load(backupFile, 'saved');
g = 'EphysPreprocessingApp';
if ispref(g)
    rmpref(g);
end
if isstruct(S.saved)
    for f = string(fieldnames(S.saved)).'
        setpref(g, char(f), S.saved.(f));
    end
    fprintf('restored %d preference(s) of %s from %s\n', numel(fieldnames(S.saved)), g, backupFile);
else
    fprintf('the backup held no %s preferences; the group is now empty\n', g);
end
end
