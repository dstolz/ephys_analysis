function meta = epsychSessionMeta(file)
%epsychSessionMeta  Cheap summary of an Epsych2 session .mat (no trial data read).
%   META = epsychSessionMeta(file) checks that FILE holds the Epsych2 variables
%   Data (one struct element per trial) and Info (the session snapshot), reads
%   only Info, and returns:
%     file, stem              path and file name without extension
%     subject                 Info.Subject (its Name field when it is a struct)
%     startTime               Info.StartTime as a datetime (NaT when absent)
%     nTrials                 elements of Data (from the file header)
%     formatVersion           Info.FormatVersion (NaN when absent)
%     dataFilename            Info.DataFilename ("" when absent)
%     hasTrialTable           Info has TrialTable / WriteParams
%
%   Errors with readEpsychSession:NotEpsych when Data or Info are missing.
%
%   See also readEpsychSession, findEpsychSessions.

arguments
    file (1,1) string
end

if ~isfile(file)
    error('readEpsychSession:NotFound', 'No such file: %s', file);
end
w = whos('-file', file);
names = string({w.name});
if ~all(ismember(["Data" "Info"], names))
    error('readEpsychSession:NotEpsych', ...
        '%s is not an Epsych2 session file (needs variables Data and Info).', file);
end
nTrials = prod(w(names == "Data").size);
if numel(w(names == "Data").size) == 2 && all(w(names == "Data").size == [0 0]); nTrials = 0; end

L = load(file, 'Info');
Info = L.Info;

[~, stem] = fileparts(char(file));
meta = struct('file', file, 'stem', string(stem), 'subject', "", 'startTime', NaT, ...
    'nTrials', nTrials, 'formatVersion', NaN, 'dataFilename', "", 'hasTrialTable', false);
if ~isstruct(Info); return; end

if isfield(Info, 'Subject')
    s = Info.Subject;
    if isstruct(s)
        for f = ["Name" "name" "ID" "id"]
            if isfield(s, f) && ~isempty(s.(f))
                meta.subject = string(s.(f));
                break
            end
        end
    elseif ischar(s) || isstring(s)
        meta.subject = string(s);
    end
end
if isfield(Info, 'StartTime')
    meta.startTime = toDatetime(Info.StartTime);
end
if isfield(Info, 'FormatVersion') && isnumeric(Info.FormatVersion) && ~isempty(Info.FormatVersion)
    meta.formatVersion = double(Info.FormatVersion(1));
end
if isfield(Info, 'DataFilename') && ~isempty(Info.DataFilename)
    meta.dataFilename = string(Info.DataFilename);
end
meta.hasTrialTable = isfield(Info, 'TrialTable') && isfield(Info, 'WriteParams');
end


function t = toDatetime(v)
t = NaT;
try
    if isdatetime(v)
        t = v;
    elseif isnumeric(v) && isscalar(v)
        t = datetime(v, 'ConvertFrom', 'datenum');
    elseif ischar(v) || isstring(v)
        t = datetime(string(v));
    end
catch
    t = NaT;
end
if ~isscalar(t); t = NaT; end
end
