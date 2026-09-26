function notes = tdtParseTbk(tbkPath)
%tdtParseTbk  Store notes of a TDT block's .Tbk file.
%   NOTES = tdtParseTbk(TBKPATH) returns a struct array, one element per
%   store, with the fields the file lists (StoreName, HeadName, Enabled,
%   SampleFreq, NumChan, ...; all char), parsed as TDTbin2mat's parseTBK
%   does: the text between the second and third [USERNOTEDELIMITER], one
%   "Name=<field>;Type=<t>;Value=<value>;" line per field, a new store at
%   each StoreName line. A missing or unreadable file gives struct([]).
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

notes = struct([]);
fid = fopen(tbkPath, 'r');
if fid < 0; return; end
txt = fread(fid, Inf, 'uint8=>char').';
fclose(fid);
delim = strfind(txt, '[USERNOTEDELIMITER]');
if numel(delim) < 3; return; end
txt = txt(delim(2):delim(3));
lines = regexp(txt, '\r?\n', 'split');
store = 0;
recs = {};
for i = 1:numel(lines) - 1                     % the last piece is the third delimiter
    line = lines{i};
    if ~isempty(strfind(line, 'StoreName')) %#ok<STREMP>
        store = store + 1;
        recs{store} = struct(); %#ok<AGROW>
    end
    if store == 0; continue; end
    eq = strfind(line, '=');
    semi = strfind(line, ';');
    if numel(eq) < 3 || numel(semi) < 3; continue; end
    field = line(eq(1) + 1:semi(1) - 1);
    value = line(eq(3) + 1:semi(3) - 1);
    if isempty(field) || ~isvarname(field); continue; end
    recs{store}.(field) = value;
end
if isempty(recs); return; end
names = {};
for k = 1:numel(recs)
    names = union(names, fieldnames(recs{k}));
end
notes = repmat(cell2struct(repmat({''}, numel(names), 1), names, 1), 1, numel(recs));
for k = 1:numel(recs)
    f = fieldnames(recs{k});
    for j = 1:numel(f)
        notes(k).(f{j}) = recs{k}.(f{j});
    end
end
end
