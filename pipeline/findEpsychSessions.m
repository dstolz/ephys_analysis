function T = findEpsychSessions(searchDirs, opts)
%findEpsychSessions  Inventory Epsych2 session files under one or more folders.
%   T = findEpsychSessions(dirs) scans every *.mat under DIRS (recursively by
%   default), keeps the ones that hold the Epsych2 variables Data + Info, and
%   returns a table with one row per session:
%     File, Stem, Subject, StartTime, NTrials, FormatVersion
%   sorted by StartTime. Only the small Info variable is read per file.
%
%   Options: Recursive (default true).
%
%   See also epsychSessionMeta, matchEpsychSession, readEpsychSession.

arguments
    searchDirs (1,:) string
    opts.Recursive (1,1) logical = true
end

File = strings(0, 1); Stem = strings(0, 1); Subject = strings(0, 1);
StartTime = NaT(0, 1); NTrials = zeros(0, 1); FormatVersion = zeros(0, 1);

for d = searchDirs
    if d == "" || ~isfolder(d); continue; end
    if opts.Recursive
        D = dir(fullfile(d, '**', '*.mat'));
    else
        D = dir(fullfile(d, '*.mat'));
    end
    for k = 1:numel(D)
        if D(k).isdir; continue; end
        f = string(fullfile(D(k).folder, D(k).name));
        try
            m = epsychSessionMeta(f);
        catch
            continue    % not an Epsych2 session (or unreadable)
        end
        File(end+1, 1)          = f;             %#ok<AGROW>
        Stem(end+1, 1)          = m.stem;        %#ok<AGROW>
        Subject(end+1, 1)       = m.subject;     %#ok<AGROW>
        StartTime(end+1, 1)     = m.startTime;   %#ok<AGROW>
        NTrials(end+1, 1)       = m.nTrials;     %#ok<AGROW>
        FormatVersion(end+1, 1) = m.formatVersion; %#ok<AGROW>
    end
end

T = table(File, Stem, Subject, StartTime, NTrials, FormatVersion);
if height(T) > 1
    T = sortrows(T, 'StartTime');
end
end
