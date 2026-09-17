function saveProbeNotes(obj, pf, notes) %#ok<INUSL>
    % Write the optional "notes" field into a probe .json with a minimal
    % textual edit (replace in place if present, otherwise insert as the
    % first field) so the file's hand-formatting is preserved.
    txt = fileread(pf);
    enc = jsonencode(string(notes));   % quoted, JSON-escaped literal
    if ~isempty(regexp(txt, '"notes"\s*:', 'once'))
        escRep = regexprep(['"notes": ' enc], '([\\$])', '\\$1');
        txt = regexprep(txt, ...
            '"notes"\s*:\s*("(?:[^"\\]|\\.)*"|null|true|false|-?[0-9.eE+]+)', ...
            escRep, 'once');
    else
        b = strfind(txt, '{');
        if isempty(b); error('not a JSON object'); end
        ins = [newline '  "notes": ' enc ','];
        txt = [txt(1:b(1)) ins txt(b(1)+1:end)];
    end
    fid = fopen(pf, 'w');
    if fid < 0; error('cannot open %s for writing', pf); end
    closer = onCleanup(@() fclose(fid));
    fwrite(fid, txt);
end
