function res = sessionResults(Rs, sessions, sp, spec, opts)
%sessionResults  A session plot's merged results: one per figure (facet x trial group).
%   RES = sessionResults(RS, SESSIONS, SP, SPEC) turns the per-session
%   results RS (a cell {1 x nSessions}; [] = none) of the sessions SESSIONS
%   (sessionTable rows, same order) into the figures of the session plot SP
%   (EphysAnalysisConfig.defaults("SessionPlot") fields), whose effective
%   spec is SPEC (EphysAnalysisConfig.sessionPlotFor). RES is a struct
%   array, one element per figure, with fields
%     facet    "all", or the subject (SP.facet "subject": one figure per
%              subject, in the order the sessions first name them; a
%              session without one is "(no subject)")
%     group    "" or the trial group (SP.trialGroups "each": the union of
%              the facet's results' group labels, in first-seen order, at
%              most SPEC.selection.maxGroups of them)
%     label    "all", the subject, or "<facet> / <group>"
%     R        the merged result (combineSessions, with SP's series, match,
%              mapping, error, showMembers, minSessions, colorOrder and
%              trialGroups) with R.spec = SPEC; [] when it could not be made
%     status   "done" | "skipped" (too few sessions or tiles:
%              combineSessions:TooFew) | "error"
%     message  why not ("" when done)
%   A heatmap keeps its trial groups as tiles with "each" (one figure); a
%   waveforms plot has none. The runner, the app's preview and the
%   standalone script all call this, so they draw the same figures.
%
%   Options
%     Mapping  match "mapping": the unit-mapping table (a cell column, one
%              per dataset key); default: SP.mappingFile read with
%              readtable(VariableNamingRule="preserve", TextType="string")
%
%   See also combineSessions, sessionTable, EphysAnalysisRunner.computeSessionPlot.

arguments
    Rs cell
    sessions table
    sp (1,1) struct
    spec (1,1) struct
    opts.Mapping = []
end

sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
Rs = reshape(Rs, 1, []);
mapping = opts.Mapping;
if sp.match == "mapping" && isempty(mapping) && strtrim(sp.mappingFile) ~= "" && isfile(sp.mappingFile)
    mapping = readMapping(sp.mappingFile);
end
res = struct('facet', {}, 'group', {}, 'label', {}, 'R', {}, 'status', {}, 'message', {});
n = height(sessions);
if n == 0; return; end
if sp.facet == "subject"
    subj = string(sessions.subject);
    subj(subj == "") = "(no subject)";
    facets = unique(subj, 'stable');
    rowsOf = arrayfun(@(f) find(subj == f), facets, 'UniformOutput', false);
else
    facets = "all";
    rowsOf = {(1:n).'};
end
kind = spec.kind;
maxGroups = Inf;
if isstruct(spec.selection) && isfield(spec.selection, 'maxGroups'); maxGroups = spec.selection.maxGroups; end
for f = 1:numel(facets)
    rows = rowsOf{f};
    Rf = Rs(rows);
    Sf = sessions(rows, :);
    groups = "";
    pass = sp.trialGroups;
    if sp.trialGroups == "each" && ~ismember(kind, ["heatmap" "waveforms"])
        groups = groupLabels(Rf);
        groups = groups(1:min(end, maxGroups));
        if isempty(groups); groups = ""; end
    end
    for g = reshape(groups, 1, [])
        grp = 0;
        if g ~= ""; grp = g; end
        label = facets(f);
        if g ~= ""; label = label + " / " + g; end
        e = struct('facet', facets(f), 'group', g, 'label', label, 'R', [], 'status', "done", 'message', "");
        try
            R = combineSessions(Rf, Sf, Series=sp.series, Match=sp.match, Mapping=mapping, Error=sp.error, ...
                ShowMembers=sp.showMembers, MinSessions=sp.minSessions, ColorOrder=sp.colorOrder, Group=grp, ...
                TrialGroups=pass, Kind=kind);
            R.spec = spec;
            e.R = R;
        catch ME
            e.status = "error";
            if ME.identifier == "combineSessions:TooFew"; e.status = "skipped"; end
            e.message = string(ME.message);
        end
        res(end+1) = e; %#ok<AGROW>
    end
end
end


function L = groupLabels(Rs)
%groupLabels  The union of the results' trial group labels, in first-seen order.
L = strings(0, 1);
for k = 1:numel(Rs)
    r = Rs{k};
    if isempty(r) || ~isfield(r, 'groups') || ~istable(r.groups); continue; end
    lab = string(r.groups.label(:));
    L = [L; lab(~ismember(lab, L))]; %#ok<AGROW>
end
end


function M = readMapping(file)
%readMapping  The unit-mapping CSV: readUnitMapping when there is one, else the table as it is.
if exist('readUnitMapping', 'file') == 2
    M = readUnitMapping(file);
else
    M = readtable(file, 'VariableNamingRule', 'preserve', 'TextType', 'string', 'Delimiter', ',', 'FileType', 'text');
end
end
