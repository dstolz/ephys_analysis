function editorRefresh(obj)
%editorRefresh  Re-parse the editor's current face (or sites), check the entry, draw the preview.
%   The face's pasted rows are parsed against its connector (guide posts
%   put back when left out); the grid shows the parsed cells. The whole
%   entry is then checked (HardwareBank.normalize + problems): the check
%   label lists the problems in red, or says it is ready in green.
E = obj.Editor;
if isempty(E) || ~isvalid(E.Fig)
    return
end
conn = obj.Bank.list("connector");
parseMsg = strings(0, 1);
ax = E.Preview;
cla(ax);
if E.Kind ~= "probe"
    txt = string(E.RowsArea.Value);
    txt = txt(strtrim(txt) ~= "");
    E.FaceText(E.FaceK) = strjoin(txt, newline);
    f = E.Faces(E.FaceK);
    f.Id = string(strtrim(E.FaceId.Value));
    f.Connector = string(E.Connector.Value);
    c = conn(strsOf(conn, 'Name') == f.Connector);
    try
        if isempty(txt)
            error('ChannelMap:BadFace', 'Paste the rows of face %s.', f.Id);
        elseif isempty(c)
            nf = ChannelMap.faceFromRows(txt, Id=f.Id, Gender=E.Gender, Connector=f.Connector);
        else
            nf = ChannelMap.faceFromRows(txt, Id=f.Id, Gender=E.Gender, Connector=f.Connector, ...
                Size=[c(1).Rows c(1).Cols], Guides=c(1).Guides, OneWay=c(1).OneWay);
        end
        f = nf;
    catch ME
        parseMsg(end + 1) = "Face " + f.Id + ": " + string(ME.message);
        f.Cells = strings(0, 0);
        f.Text = strings(0, 1);
    end
    E.Faces(E.FaceK) = f;
    if isempty(f.Cells)
        E.Grid.Data = table();
        axis(ax, 'off');
    else
        E.Grid.Data = array2table(f.Cells, 'VariableNames', cellstr(compose("%d", 1:size(f.Cells, 2))));
        E.Grid.ColumnWidth = repmat({46}, 1, size(f.Cells, 2));
        hold(ax, 'on');
        ChannelMapperApp.drawFace(ax, f, Caption=sprintf("%s (%s, looking into it)", f.Id, E.Gender));
        hold(ax, 'off');
        ax.YDir = 'reverse';
        axis(ax, 'equal');
        axis(ax, 'off');
        xlim(ax, [0.3, size(f.Cells, 2) + 0.7]);
        ylim(ax, [-0.6, size(f.Cells, 1) + 0.6]);
    end
else
    S = E.Sites.Data;
    axis(ax, 'off');
    if height(S) > 0
        axis(ax, 'on');
        scatter(ax, S.X, S.Y, 36, S.Shank, 'filled');
        hold(ax, 'on');
        text(ax, S.X + 4, S.Y, string(S.Site), 'FontSize', 7, 'Clipping', 'on', 'HitTest', 'off');
        hold(ax, 'off');
        axis(ax, 'equal');
        grid(ax, 'on');
        xlabel(ax, 'x (\mum)');
        ylabel(ax, 'y (\mum)');
    end
end
obj.Editor = E;

raw = obj.editorEntry();
e = HardwareBank.normalize(raw, "");
keep = ~startsWith(e.Problems, "Its schema");
if E.Kind ~= "probe"
    keep = keep & ~startsWith(e.Problems, "Face " + E.Faces(E.FaceK).Id + ":");   % already in parseMsg
end
p = [parseMsg(:); e.Problems(keep); HardwareBank.problems(e, conn)];
if E.Kind == "headstage"
    try
        v = ChannelMapperApp.parseChannelList(E.HardwareRange.Value);
        if isempty(v); error('x:y', ''); end
    catch
        if strtrim(string(E.HardwareRange.Value)) ~= ""
            p(end + 1) = "Hardware channels: write a range such as 0-31.";
        end
    end
end
p = unique(p, 'stable');
id = HardwareBank.entryId(E.Kind, HardwareBank.safeName(lower(e.Manufacturer)), HardwareBank.safeName(e.Name));
if isempty(p)
    msg = "Ready to save as " + id + ".";
    if obj.Bank.has(id)
        msg = msg + " It replaces the entry of that name.";
    end
    E.Check.Text = char(msg);
    E.Check.FontColor = [0 0.5 0];
    E.SaveButton.Enable = 'on';
else
    E.Check.Text = char(sprintf("%d problem(s):", numel(p)) + newline + strjoin("  " + p(:)', newline));
    E.Check.FontColor = [0.75 0 0];
    E.SaveButton.Enable = 'off';
end
obj.Editor = E;
end
