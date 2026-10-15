function [s, warn] = legacyMigrate(s)
%legacyMigrate  Turn a version-1 config struct into a version-2 one: its plots and session plots become figures.
%   [S, WARN] = legacyMigrate(S) takes a decoded version-1 analysis config
%   (schema "ephys-analysis-config", version 1) and returns it as version 2
%   with WARN, the load warnings the migration raised (a string row).
%   EphysAnalysisConfig.fromStruct calls it once, for a struct whose
%   version is 1; nothing else uses it.
%
%   Plots       every entry (legacyNormalizePlot) becomes a figure through
%               legacyPlotToFigure, its id the plot's own; every note the
%               converter makes is a warning "plot <id> migrated to figure
%               <id>: <note>". A behavior plot (figures have no panel
%               type for it) or a kind version 1 did not have is not
%               migrated: a warning says so.
%   SessionPlots  every entry becomes a session figure: its base plot
%               (plot, by id) converted as above with the session plot's
%               layout when it has one, then the session plot's id,
%               enabled flag, title (when not "") and looks (its
%               aesthetics after the base plot's, both through
%               legacyLooks), and sessions filled from
%               its fields: enabled true, datasets, datasetKeys, facet,
%               series, colorOrder, showMembers, error, match, mappingFile,
%               minSessions, trialGroups. match "pool" becomes "site" (a
%               session figure observes one matched unit; a note when it
%               observes units); a data list other than "results" is a
%               note (a session figure's data file holds its figures). The
%               notes are warnings "session plot <id> migrated to session
%               figure <id>: <note>". One without its base plot, or whose
%               base plot cannot be converted, is not migrated: a warning.
%   Order       the migrated plots first, then the file's own figures, then
%               the migrated session plots. An id that names the same files
%               as one already taken (case and the characters {Plot}
%               replaces ignored) gets "_2", "_3", ... and a warning.
%   Unknown fields of a plot or session plot are dropped and listed, as
%   version 1 listed them ("Plots: dropped unknown field(s) ...").
%
%   See also legacyPlotToFigure, legacyNormalizePlot, legacyPlotDefaults,
%   EphysAnalysisConfig.fromStruct, EphysAnalysisConfig.load.

warn = string.empty(1, 0);
D = EphysAnalysisConfig.defaults("Defaults");
if isfield(s, 'Defaults') && isstruct(s.Defaults)
    D = EphysAnalysisConfig.normalizeSection("Defaults", s.Defaults);
end

% --- the file's own figures keep their ids ---------------------------------------------------------
own = {};
if isfield(s, 'Figures') && ~isempty(s.Figures)
    own = s.Figures;
    if isstruct(own); own = num2cell(own); end
end
used = strings(1, 0);
for k = 1:numel(own)
    if isstruct(own{k}) && isfield(own{k}, 'id'); used(end+1) = fileKey(own{k}.id); end %#ok<AGROW>
end

% --- the plots -------------------------------------------------------------------------------------
plots = readList(s, 'Plots', "Plot");
P = cell(1, numel(plots));
for k = 1:numel(plots)
    if plots{k}.id == ""
        plots{k}.id = EphysAnalysisConfig.freeId(plots{k}.kind, idsOf(plots));
    end
end
for k = 1:numel(plots)
    p = plots{k};
    try
        [f, notes] = legacyPlotToFigure(p, D);
    catch ME
        if ME.identifier ~= "EphysAnalysisConfig:NotConvertible"; rethrow(ME); end
        warn(end+1) = "plot " + p.id + " not migrated: " + string(ME.message); %#ok<AGROW>
        continue
    end
    [f.id, used, renamed] = freeFileId(p.id, used);
    head = "plot " + p.id + " migrated to figure " + f.id + ": ";
    if renamed; warn(end+1) = head + "its id names the same files as another figure's, so it was renamed."; end %#ok<AGROW>
    warn = [warn, head + notes]; %#ok<AGROW>
    P{k} = f;
end
P = P(~cellfun(@isempty, P));

% --- the session plots -----------------------------------------------------------------------------
sessionPlots = readList(s, 'SessionPlots', "SessionPlot");
SP = cell(1, numel(sessionPlots));
for k = 1:numel(sessionPlots)
    sp = sessionPlots{k};
    if sp.id == ""
        base = "sessions";
        if sp.plot ~= ""; base = sp.plot + "_sessions"; end
        sp.id = EphysAnalysisConfig.freeId(base, idsOf(sessionPlots));
        sessionPlots{k}.id = sp.id;
    end
    b = find(cellfun(@(q) q.id == sp.plot, plots), 1);
    if isempty(b)
        warn(end+1) = "session plot " + sp.id + " not migrated: no base plot """ + sp.plot + """."; %#ok<AGROW>
        continue
    end
    try
        [f, notes] = legacyPlotToFigure(plots{b}, D, sp.layout);
    catch ME
        if ME.identifier ~= "EphysAnalysisConfig:NotConvertible"; rethrow(ME); end
        warn(end+1) = "session plot " + sp.id + " not migrated: " + string(ME.message); %#ok<AGROW>
        continue
    end
    f.enabled = sp.enabled;
    if sp.title ~= ""; f.title = sp.title; end
    [spLooks, lookNotes] = legacyLooks(sp.aesthetics);   % the session plot's own looks, as the base plot's were
    f.aesthetics = [reshape(f.aesthetics, 1, []), reshape(spLooks, 1, [])];
    notes = [notes, lookNotes]; %#ok<AGROW>
    x = EphysAnalysisConfig.defaults("FigureSessions");
    x.enabled = true;
    for g = ["datasets" "datasetKeys" "facet" "series" "colorOrder" "showMembers" "error" "match" "mappingFile" "minSessions" "trialGroups"]
        x.(g) = sp.(g);
    end
    observesUnits = EphysAnalysisConfig.observeKind(f) == "unit";
    if sp.match == "pool"
        x.match = "site";
        if observesUnits
            notes(end+1) = "match ""pool"" (every session's units pooled) is not available: a session figure observes " + ...
                "one unit matched across the sessions; it became ""site"" (the unit's recording channel)."; %#ok<AGROW>
        end
    elseif sp.match == "mapping" && ~observesUnits
        x.match = "site";
        x.mappingFile = "";   % read only by match "mapping"
        notes(end+1) = "match ""mapping"" names units, but this session figure observes a " + EphysAnalysisConfig.observeKind(f) + ...
            ": it became ""site"" (channels match by recording channel; a dataset needs no match)."; %#ok<AGROW>
    end
    extra = setdiff(reshape(string(sp.data), 1, []), ["results" ""], 'stable');   % an empty data list: no note
    if ~isempty(extra)
        notes(end+1) = "data """ + strjoin(extra, ", ") + """ is not carried: a session figure's data file (Export.Data) " + ...
            "holds its merged and per-session figures only."; %#ok<AGROW>
    end
    f.sessions = x;
    f = EphysAnalysisConfig.normalizeFigure(f, "Figure");
    [f.id, used, renamed] = freeFileId(sp.id, used);
    head = "session plot " + sp.id + " migrated to session figure " + f.id + ": ";
    if renamed; warn(end+1) = head + "its id names the same files as another figure's, so it was renamed."; end %#ok<AGROW>
    warn = [warn, head + notes]; %#ok<AGROW>
    SP{k} = f;
end
SP = SP(~cellfun(@isempty, SP));

s.Figures = [P, reshape(own, 1, []), SP];
if isfield(s, 'Plots'); s = rmfield(s, 'Plots'); end
if isfield(s, 'SessionPlots'); s = rmfield(s, 'SessionPlots'); end
s.version = EphysAnalysisConfig.Version;
nPlots = numel(plots);
nSessions = numel(sessionPlots);
if nPlots + nSessions > 0
    warn = ["config version 1: " + numel(P) + " of " + nPlots + " plot(s) and " + numel(SP) + " of " + nSessions + ...
        " session plot(s) migrated to figures; saving writes version 2", warn];
end


    function L = readList(s, field, section)
        %readList  A version-1 list (Plots / SessionPlots) as a cell of normalized entries; unknown fields to WARN.
        L = {};
        if ~isfield(s, field) || isempty(s.(field)); return; end
        v = s.(field);
        if isstruct(v)
            v = num2cell(v);
        elseif ~iscell(v)
            error('EphysAnalysisConfig:BadValue', '%s must be a struct array or a cell array of structs.', field);
        end
        unknown = string.empty(1, 0);
        L = cell(1, numel(v));
        for i = 1:numel(v)
            [L{i}, u] = legacyNormalizePlot(v{i}, string(field) + "(" + i + ")", section);
            unknown = [unknown, u]; %#ok<AGROW>
        end
        if ~isempty(unknown)
            warn(end+1) = string(field) + ": dropped unknown field(s) " + strjoin(unknown, ", ");
        end
    end
end


function ids = idsOf(L)
%idsOf  The ids of a cell of entries, a string row.
ids = strings(1, numel(L));
for i = 1:numel(L); ids(i) = L{i}.id; end
end


function k = fileKey(id)
%fileKey  An id as {Plot} writes it into a file name, case-blind (Windows).
k = lower(regexprep(string(id), '[^\w\-\.]', '_'));
end


function [id, used, renamed] = freeFileId(id, used)
%freeFileId  ID, or ID_2, ID_3, ... when an id taken names the same files; USED gains it.
base = id;
n = 1;
while any(used == fileKey(id))
    n = n + 1;
    id = base + "_" + n;
end
renamed = n > 1;
used(end+1) = fileKey(id);
end
