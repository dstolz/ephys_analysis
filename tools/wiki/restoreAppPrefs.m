function restoreAppPrefs(backupFile)
%restoreAppPrefs  Put back app preferences from a screenshot run's backup .mat.
%   restoreAppPrefs(BACKUPFILE) replaces each preference group saved in
%   BACKUPFILE (variable 'saved': one field per group, holding the group's
%   struct, or [] when the group did not exist) with what was saved.
%   wikiScreenshots and wikiToolScreenshots write it to
%   OUTFOLDER/prefs_backup.mat and call this when they end. Run it by hand
%   when a run had to be killed before it could. Check first that no other
%   app-driving MATLAB is running.
%
%   See also wikiScreenshots, wikiToolScreenshots.

arguments
    backupFile (1,1) string {mustBeFile}
end
S = load(backupFile, 'saved');
for g = fieldnames(S.saved).'
    g = g{1}; %#ok<FXSET>
    if ispref(g)
        rmpref(g);
    end
    P = S.saved.(g);
    if isstruct(P)
        for f = fieldnames(P).'
            setpref(g, f{1}, P.(f{1}));
        end
        fprintf('restored %d preference(s) of %s from %s\n', numel(fieldnames(P)), g, backupFile);
    else
        fprintf('the backup held no %s preferences; the group is now empty\n', g);
    end
end
end
