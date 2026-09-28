function raw = editorEntry(obj)
%editorEntry  The entry the editor describes, as a raw JSON struct (what saveEntry takes).
%   A face that parsed is written as its canonical rows (guide posts
%   included); one that did not keeps the pasted text, so its problem shows.
E = obj.Editor;
raw = struct();
raw.schema = char(HardwareBank.Schema);
raw.kind = char(E.Kind);
raw.manufacturer = char(lower(strtrim(string(E.Manufacturer.Value))));
raw.name = char(strtrim(string(E.Name.Value)));
raw.model = char(E.Model.Value);
raw.channels = E.Channels.Value;
sameName = ~E.IsNew && string(raw.name) == E.Base.Name && string(raw.manufacturer) == E.Base.Manufacturer;
switch E.Kind
    case "headstage"
        raw.channelLabel = char(E.ChannelLabel.Value);
        raw.hardwareChannels = [];
        try
            v = ChannelMapperApp.parseChannelList(E.HardwareRange.Value);
            raw.hardwareChannels = [min(v) max(v)];
        catch
        end
        raw.view = char(E.Base.View);
    case "package"
        raw.view = char(E.Base.View);
        raw.verifiedHeadstages = {};
        if sameName
            raw.verifiedHeadstages = cellstr(E.Base.VerifiedHeadstages(:))';
        end
    case "probe"
        S = E.Sites.Data;
        raw.shanks = numel(unique(S.Shank));
        raw.sites = double(S.Site);
        raw.x = double(S.X);
        raw.y = double(S.Y);
        raw.shank = double(S.Shank);
        raw.defaultPackage = char(E.DefaultPackage.Value);
        raw.template = char(E.Template);
        raw.pitchUm = E.PitchUm;
        src = E.GeometrySource;
        if src == ""; src = "editor"; end
        raw.geometrySource = char(src);
end
if E.Kind ~= "probe"
    faces = cell(1, numel(E.Faces));
    for k = 1:numel(E.Faces)
        f = E.Faces(k);
        if ~isempty(f.Cells)
            rows = f.Text;
        else
            rows = splitlines(E.FaceText(k));
            rows = rows(strtrim(rows) ~= "");
        end
        one = struct('id', char(f.Id), 'connector', char(f.Connector), 'gender', char(E.Gender));
        one.rows = cellstr(rows(:));
        faces{k} = one;
    end
    raw.faces = faces;
end
raw.notes = char(E.Notes.Value);
raw.source = char(E.Source.Value);
end
