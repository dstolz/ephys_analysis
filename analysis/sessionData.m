function S = sessionData(sp, spec, sessions, Rs, res, opts)
%sessionData  A session plot's data as one run-independent struct.
%   S = sessionData(SP, SPEC, SESSIONS, RS, RES, Config=, Epochs=, Files=,
%   Provenance=) assembles what writeAnalysisData saves and the app puts in
%   the workspace. The inputs are those of a session plot's compute
%   (EphysAnalysisRunner.computeSessionPlot): the session plot SP
%   (EphysAnalysisConfig.defaults("SessionPlot") fields), its effective spec
%   SPEC, the SESSIONS table (sessionTable, with status and message), the
%   per-session results RS ({1 x nSessions}, [] = none) and the merged
%   results RES (sessionResults). Pure: no I/O.
%
%   S fields
%     schema       "ephys-analysis-sessions/1"
%     sessionPlot  SP
%     spec         SPEC, the effective spec every session was computed with
%     sessions     SESSIONS plus nItems (units or channels of the session's
%                  result; behavior: its values) and nEpochs (rows of its
%                  epochs) from RS; 0 where it has no result
%     results      struct array, one per figure: facet, group, label, status,
%                  message, R (the merged result; combineSessions' contract),
%                  files (the figure files written, "" row when none)
%     perSession   {1 x nSessions} the base result of each session (computePlot's
%                  R; [] where none), when SP.data holds "results"; else {}
%     epochs       {1 x nSessions} epochData of each session ([] where none:
%                  Epochs{k} is stored as given), when SP.data holds "epochs"
%                  (and "signals" for the epoched samples, which the caller
%                  asks epochData for); else {}
%     config       the analysis config as a struct (EphysAnalysisConfig.toStruct)
%     created      when, yyyy-MM-dd HH:mm:ss
%     provenance   ephysProvenance(): the code, MATLAB and machine
%
%   Options
%     Config      struct stored as S.config (default struct())
%     Epochs      cell {1 x nSessions} of epochData results (default {})
%     Files       cell, one string row of figure files per element of RES
%                 (default {}: none)
%     Provenance  ephysProvenance() to store (default: made here)
%
%   epochLongTable turns S into tidy tables; writeAnalysisData saves it
%   (each field is a variable of the .mat file).
%
%   See also epochData, writeAnalysisData, epochLongTable, combineSessions,
%   sessionResults, EphysAnalysisRunner.sessionData.
arguments
    sp (1,1) struct
    spec (1,1) struct
    sessions table
    Rs cell
    res struct
    opts.Config = struct()
    opts.Epochs cell = {}
    opts.Files cell = {}
    opts.Provenance = []
end

sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
n = height(sessions);
Rs = reshape(Rs, 1, []);
if numel(Rs) ~= n
    error('sessionData:Size', 'RS has %d entries for %d sessions.', numel(Rs), n);
end
nItems = zeros(n, 1);
nEpochs = zeros(n, 1);
for k = 1:n
    r = Rs{k};
    if isempty(r); continue; end
    if isfield(r, 'kind') && r.kind == "behavior"
        nItems(k) = height(r.values);
    elseif isfield(r, 'labels')
        nItems(k) = numel(r.labels);
    end
    if isfield(r, 'epochs') && istable(r.epochs); nEpochs(k) = height(r.epochs); end
end
T = sessions;
T.nItems = nItems;
T.nEpochs = nEpochs;

figs = struct('facet', {}, 'group', {}, 'label', {}, 'status', {}, 'message', {}, 'R', {}, 'files', {});
for i = 1:numel(res)
    files = strings(1, 0);
    if i <= numel(opts.Files); files = reshape(string(opts.Files{i}), 1, []); end
    figs(1, i) = struct('facet', string(res(i).facet), 'group', string(res(i).group), 'label', string(res(i).label), ...
        'status', string(res(i).status), 'message', string(res(i).message), 'R', res(i).R, 'files', files);
end

what = string(sp.data);
S = struct();
S.schema = "ephys-analysis-sessions/1";
S.sessionPlot = sp;
S.spec = spec;
S.sessions = T;
S.results = figs;
S.perSession = {};
if any(what == "results"); S.perSession = Rs; end
S.epochs = {};
if any(what == "epochs")
    S.epochs = reshape(opts.Epochs, 1, []);
end
S.config = opts.Config;
S.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
if isempty(opts.Provenance)
    S.provenance = ephysProvenance();
else
    S.provenance = opts.Provenance;
end
end
