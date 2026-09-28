function [E, msgs] = tdtEpocs(S, notes, keep)
%tdtEpocs  A block's epoc stores as TDTbin2mat returns them.
%   [E, MSGS] = tdtEpocs(S, NOTES, KEEP) builds the epoc stores from a
%   tdtScanTsq result S and the .Tbk store notes NOTES (tdtParseTbk; may be
%   empty). KEEP is a logical row over S.stores (false for disabled
%   stores). E is a struct array, one element per onset store in order of
%   appearance, with
%     name     store name          buddy   its offset store ('' if none)
%     onset    [n x 1] s from the block start (rounded to the 195312.5 Hz tick)
%     offset   [n x 1] s; Inf where TDTbin2mat has Inf, NaN where the store
%              has fewer offsets than onsets (see MSGS)
%     value    [n x 1] the strobe values (double)
%     icon     true when the iCon rule was applied (see below)
%   following TDTbin2mat (full-block read, NOEPOCAUTO false):
%   - an onset store without a buddy offset store: offset = the next onset,
%     Inf for the last;
%   - with a buddy: offset = the buddy's times; a first offset before the
%     first onset adds an onset at 0 with the first value; a last onset
%     after the last offset adds an Inf offset; an offset store whose buddy
%     is not an onset store is skipped (listed in MSGS);
%   - a secondary epoc (its .Tbk HeadName holds '|') takes its primary's
%     offsets (the last 4 characters of HeadName);
%   - iCon epocs (values exactly 3 and 4): value-3 events are the onsets,
%     value-4 events the offsets, values 1.
%   MSGS also lists stores whose onset / offset counts still differ after
%   these rules: the extra offsets are dropped, missing ones are NaN.
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

msgs = {};
E = struct('name', {}, 'buddy', {}, 'onset', {}, 'offset', {}, 'value', {}, 'icon', {});
st = S.stores;
isEpoc = strcmp({st.typeStr}, 'epocs') & keep;

% onset stores
for k = find(isEpoc & strcmp({st.epocType}, 'onset'))
    e.name = st(k).name;
    e.buddy = '';
    ts = S.epocTs{k};
    e.onset = ts;
    e.offset = [ts(2:end); Inf];
    e.value = S.epocVal{k};
    e.icon = false;
    E(end + 1) = e; %#ok<AGROW>
end

% buddy offset stores
for k = find(isEpoc & strcmp({st.epocType}, 'offset'))
    b = st(k).buddy;
    j = find(strcmp({E.name}, b), 1);
    if isempty(j)
        msgs{end + 1} = sprintf('%s: its buddy epoc %s was not found; skipped.', st(k).name, b); %#ok<AGROW>
        continue
    end
    E(j).buddy = st(k).name;
    off = S.epocTs{k};
    E(j).offset = off;
    if ~isempty(off) && ~isempty(E(j).onset) && off(1) < E(j).onset(1)
        E(j).onset = [0; E(j).onset];
        E(j).value = [E(j).value(1); E(j).value];
    end
    if ~isempty(E(j).onset) && (isempty(off) || E(j).onset(end) > off(end))
        E(j).offset = [off; Inf];
    end
end

% secondary epocs take their primary's offsets
if ~isempty(notes) && isfield(notes, 'StoreName') && isfield(notes, 'HeadName')
    for j = 1:numel(E)
        n = find(strcmp({notes.StoreName}, E(j).name), 1);
        if isempty(n); continue; end
        head = notes(n).HeadName;
        if isempty(strfind(head, '|')) || numel(head) < 4; continue; end %#ok<STREMP>
        p = find(strcmp({E.name}, deblank(head(end - 3:end))), 1);
        if ~isempty(p) && p ~= j
            E(j).offset = E(p).offset;
        end
    end
end

% iCon epocs: values 3 (onset) and 4 (offset)
for j = 1:numel(E)
    u = unique(E(j).value);
    if isequal(u(:), [3; 4])
        on = E(j).value == 3;
        off = E(j).onset(E(j).value == 4);
        E(j).onset = E(j).onset(on);
        E(j).value = ones(nnz(on), 1);
        E(j).offset = off;
        E(j).icon = true;
    end
end

% one offset per onset
for j = 1:numel(E)
    n = numel(E(j).onset);
    m = numel(E(j).offset);
    E(j).onset = reshape(E(j).onset, [], 1);
    E(j).value = reshape(E(j).value, [], 1);
    E(j).offset = reshape(E(j).offset, [], 1);
    if m > n
        msgs{end + 1} = sprintf('%s: %d onsets but %d offsets; the last %d offsets are dropped.', ...
            E(j).name, n, m, m - n); %#ok<AGROW>
        E(j).offset = E(j).offset(1:n);
    elseif m < n
        msgs{end + 1} = sprintf('%s: %d onsets but %d offsets; the last %d onsets have no offset (NaN).', ...
            E(j).name, n, m, n - m); %#ok<AGROW>
        E(j).offset = [E(j).offset; NaN(n - m, 1)];
    end
end
end
