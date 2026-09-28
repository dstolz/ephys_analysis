classdef HardwareBank < handle
%HardwareBank  The channel mapper's hardware definitions, read from JSON files.
%   BANK = HardwareBank() reads every entry under pipeline/hardware;
%   HardwareBank(FOLDER) reads another bank. The folder is laid out as
%     connectors/<name>.json                  connector families (grid, guide posts)
%     headstages/<manufacturer>/<name>.json   headstage faces (0-based channels)
%     packages/<manufacturer>/<name>.json     probe package faces (site numbers)
%     adaptors/<manufacturer>/<name>.json     (reserved: adaptors are not supported yet)
%     probes/<manufacturer>/<name>.json       probe designs (site geometry)
%     mappings/<name>.json                    saved chains (ChannelMapperApp)
%   Every file carries "schema": "ephys-hardware/1" and its "kind", which
%   must match its folder; see pipeline/hardware/README.md for the schemas.
%
%   Entries holds one normalized struct per file (the same fields for every
%   kind): Id ("neuronexus/H32"; a connector's or mapping's Id is its name),
%   Kind, Manufacturer, Name, Channels, Model, Notes, Source, File, View,
%   ChannelLabel, HardwareChannels, Faces (see ChannelMap.faceFromRows),
%   VerifiedHeadstages, Family, Rows, Cols, Guides, OneWay, PitchMm, Shanks,
%   Sites, X, Y, Shank, DefaultPackage, Template, PitchUm, GeometrySource,
%   Mapping, Problems (string column; empty = usable).
%
%   Methods
%     reload                          read the folder again
%     E = list(kind, Channels=, Manufacturer=)   entries of a kind, sorted
%     m = manufacturers(kind)         n = channelCounts(kind, manufacturer)
%     e = get(id)                     error HardwareBank:NotFound
%     tf = has(id)
%     file = saveEntry(e, Overwrite=) write an entry (normalized or raw JSON struct)
%     chain = chainFromMapping(m)     a saved mapping -> ChannelMap chain
%   Static: normalize, problems, encode, defaultFolder, stringList, numList,
%   structList, entryId, kindFolder, emptyEntry.
%
%   See also ChannelMap, ChannelMapperApp.

    properties (Constant)
        Schema = "ephys-hardware/1"
        Kinds = ["connector" "headstage" "package" "adaptor" "probe" "mapping"]
        KindFolders = ["connectors" "headstages" "packages" "adaptors" "probes" "mappings"]
    end

    properties
        Folder (1,1) string = ""
        Entries struct = HardwareBank.emptyEntry()
    end

    methods
        function obj = HardwareBank(folder)
            arguments
                folder (1,1) string = HardwareBank.defaultFolder()
            end
            if folder == ""
                folder = HardwareBank.defaultFolder();
            end
            obj.Folder = folder;
            obj.reload();
        end

        function reload(obj)
            %reload  Read every entry of the bank folder again.
            E = HardwareBank.emptyEntry();
            E = E([]);
            for k = 1:numel(HardwareBank.Kinds)
                kind = HardwareBank.Kinds(k);
                D = dir(fullfile(obj.Folder, HardwareBank.KindFolders(k), '**', '*.json'));
                for d = D(:)'
                    if startsWith(d.name, "~")
                        continue    % a writeJsonFile temporary
                    end
                    file = string(fullfile(d.folder, d.name));
                    raw = readJsonFile(file, ErrorOnFail=false);
                    if isempty(raw)
                        e = HardwareBank.emptyEntry();
                        e.Kind = kind;
                        [~, nm] = fileparts(file);
                        e.Name = string(nm);
                        e.Id = HardwareBank.entryId(kind, "", e.Name);
                        e.File = file;
                        e.Problems = "Not valid JSON.";
                    else
                        e = HardwareBank.normalize(raw, file);
                        if e.Kind ~= kind
                            e.Problems(end + 1, 1) = sprintf("Its kind is ""%s"" but it sits in %s/.", ...
                                e.Kind, HardwareBank.KindFolders(k));
                        end
                    end
                    E(end + 1, 1) = e; %#ok<AGROW>
                end
            end

            % connector details onto the faces, then the checks that need the whole bank
            conn = E(strs(E, "Kind") == "connector");
            for i = 1:numel(E)
                for f = 1:numel(E(i).Faces)
                    c = conn(strs(conn, "Name") == E(i).Faces(f).Connector);
                    if ~isempty(c)
                        E(i).Faces(f).OneWay = c(1).OneWay;
                    end
                end
            end
            ids = strs(E, "Id");
            for i = 1:numel(E)
                p = [E(i).Problems; HardwareBank.problems(E(i), conn)];
                if sum(ids == E(i).Id) > 1
                    p(end + 1, 1) = "Another file has the same id " + E(i).Id + "."; %#ok<AGROW>
                end
                if E(i).Kind == "mapping"
                    p = [p; mappingRefProblems(E(i).Mapping, ids)]; %#ok<AGROW>
                end
                E(i).Problems = unique(p, 'stable');
            end
            obj.Entries = E;
        end

        function E = list(obj, kind, opts)
            %list  Entries of one kind, sorted by manufacturer, channels and name.
            arguments
                obj
                kind (1,1) string
                opts.Channels (1,1) double = NaN
                opts.Manufacturer (1,1) string = ""
            end
            E = obj.Entries(strs(obj.Entries, "Kind") == kind);
            if ~isnan(opts.Channels)
                E = E([E.Channels] == opts.Channels);
            end
            if opts.Manufacturer ~= ""
                E = E(strs(E, "Manufacturer") == opts.Manufacturer);
            end
            if ~isempty(E)
                [~, i] = sortrows([lower(strs(E, "Manufacturer"))', compose("%06d", [E.Channels]'), lower(strs(E, "Name"))']);
                E = E(i);
            end
        end

        function m = manufacturers(obj, kind)
            %manufacturers  The manufacturers of one kind's entries, sorted.
            E = obj.list(kind);
            m = unique(strs(E, "Manufacturer"));
            m = m(:)';
        end

        function n = channelCounts(obj, kind, manufacturer)
            %channelCounts  The channel counts of one kind's entries ("" = any manufacturer).
            arguments
                obj
                kind (1,1) string
                manufacturer (1,1) string = ""
            end
            E = obj.list(kind, Manufacturer=manufacturer);
            n = unique([E.Channels]);
            n = n(isfinite(n));
        end

        function e = get(obj, id)
            %get  The entry with this id (error HardwareBank:NotFound).
            i = find(strs(obj.Entries, "Id") == string(id), 1);
            if isempty(i)
                error('HardwareBank:NotFound', 'No hardware entry "%s" in %s.', id, obj.Folder);
            end
            e = obj.Entries(i);
        end

        function tf = has(obj, id)
            %has  True when the bank has an entry with this id.
            tf = any(strs(obj.Entries, "Id") == string(id));
        end

        function file = saveEntry(obj, e, opts)
            %saveEntry  Write an entry to <Folder>/<kind folder>/<manufacturer>/<name>.json.
            %   FILE = BANK.saveEntry(E) takes a normalized entry or a raw JSON
            %   struct (lowercase fields, as in the files), checks it
            %   (HardwareBank:Invalid, with the problems), refuses to replace
            %   a file unless Overwrite=true (HardwareBank:Exists), writes it
            %   atomically and reloads the bank. The name is made file-safe.
            arguments
                obj
                e (1,1) struct
                opts.Overwrite (1,1) logical = false
            end
            if isfield(e, 'kind')
                e = HardwareBank.normalize(e, "");
            end
            e.Name = HardwareBank.safeName(e.Name);
            if e.Kind ~= "connector" && e.Kind ~= "mapping"
                e.Manufacturer = HardwareBank.safeName(lower(e.Manufacturer));
            end
            e.Id = HardwareBank.entryId(e.Kind, e.Manufacturer, e.Name);
            conn = obj.Entries(strs(obj.Entries, "Kind") == "connector");
            p = [e.Problems(~startsWith(e.Problems, "Its schema")); HardwareBank.problems(e, conn)];
            if e.Kind == "mapping"
                p = [p; mappingRefProblems(e.Mapping, strs(obj.Entries, "Id"))];
            end
            if ~isempty(p)
                error('HardwareBank:Invalid', 'Not saved, %s has problems:\n  %s', e.Id, strjoin(p, newline + "  "));
            end
            file = obj.entryFile(e);
            if isfile(file) && ~opts.Overwrite
                error('HardwareBank:Exists', '%s already exists.', file);
            end
            writeJsonFile(file, HardwareBank.encode(e));
            obj.reload();
        end

        function file = entryFile(obj, e)
            %entryFile  Where an entry is (or would be) stored.
            folder = fullfile(obj.Folder, HardwareBank.kindFolder(e.Kind));
            if e.Kind ~= "connector" && e.Kind ~= "mapping"
                folder = fullfile(folder, e.Manufacturer);
            end
            file = fullfile(folder, e.Name + ".json");
        end

        function chain = chainFromMapping(obj, m)
            %chainFromMapping  A saved mapping (entry or its Mapping struct) -> ChannelMap chain.
            %   Errors HardwareBank:NotFound when a device it names is not in
            %   the bank.
            if isfield(m, 'Mapping')
                m = m.Mapping;
            end
            chain = struct();
            chain.probe = [];
            if m.Probe ~= ""
                chain.probe = obj.get(m.Probe);
            end
            chain.package = obj.get(m.Package);
            chain.adaptors = {};
            hs = struct('Entry', {}, 'ChannelOffset', {});
            for i = 1:numel(m.Headstages)
                hs(end + 1) = struct('Entry', obj.get(m.Headstages(i).Id), ...
                    'ChannelOffset', m.Headstages(i).ChannelOffset); %#ok<AGROW>
            end
            chain.headstages = hs;
            chain.mates = m.Mates;
            chain.rowsMode = m.RowsMode;
            chain.dataset = m.Dataset;
            chain.channelNumbers = [];
            if m.RowsMode ~= "in-order"
                chain.channelNumbers = m.ChannelNumbers(:)';
            end
        end
    end

    methods (Static)
        function f = defaultFolder()
            %defaultFolder  pipeline/hardware.
            f = string(fullfile(fileparts(mfilename('fullpath')), 'hardware'));
        end

        function f = kindFolder(kind)
            %kindFolder  "headstage" -> "headstages".
            f = HardwareBank.KindFolders(HardwareBank.Kinds == string(kind));
            if isempty(f)
                error('HardwareBank:BadKind', 'Unknown hardware kind "%s".', kind);
            end
        end

        function id = entryId(kind, manufacturer, name)
            %entryId  "<manufacturer>/<name>", or the name for connectors and mappings.
            if any(string(kind) == ["connector" "mapping"]) || string(manufacturer) == ""
                id = string(name);
            else
                id = string(manufacturer) + "/" + string(name);
            end
        end

        function n = safeName(n)
            %safeName  File-safe name, as ProbeDesignerApp does (no .json ending).
            n = regexprep(strtrim(string(n)), '[^\w\-.]', '_');
            if endsWith(lower(n), ".json")
                n = extractBefore(n, strlength(n) - 4);
            end
        end

        function e = emptyEntry()
            %emptyEntry  A normalized entry with every field at its default.
            e = struct();
            e.Id = "";
            e.Kind = "";
            e.Manufacturer = "";
            e.Name = "";
            e.Channels = NaN;
            e.Model = "";
            e.Notes = "";
            e.Source = "";
            e.File = "";
            e.View = "";
            e.ChannelLabel = "";
            e.HardwareChannels = zeros(0, 1);
            e.Faces = ChannelMap.emptyFaces();
            e.VerifiedHeadstages = strings(0, 1);
            e.Family = "";
            e.Rows = NaN;
            e.Cols = NaN;
            e.Guides = zeros(0, 2);
            e.OneWay = false;
            e.PitchMm = NaN;
            e.Shanks = NaN;
            e.Sites = zeros(0, 1);
            e.X = zeros(0, 1);
            e.Y = zeros(0, 1);
            e.Shank = zeros(0, 1);
            e.DefaultPackage = "";
            e.Template = "";
            e.PitchUm = NaN;
            e.GeometrySource = "";
            e.Mapping = HardwareBank.emptyMapping();
            e.Problems = strings(0, 1);
        end

        function m = emptyMapping()
            %emptyMapping  A normalized mapping with nothing in it.
            m = struct('Probe', "", 'Package', "", 'Adaptors', strings(0, 1), ...
                'Headstages', struct('Id', {}, 'ChannelOffset', {}), ...
                'Mates', struct('From', {}, 'To', {}, 'Orientation', {}), ...
                'RowsMode', "in-order", 'ChannelNumbers', zeros(0, 1), 'Dataset', "", ...
                'Result', struct('Site', zeros(0, 1), 'HardwareChannel', zeros(0, 1), 'RecordingRow0', zeros(0, 1)), ...
                'SavedProblems', strings(0, 1), 'Trust', "");
        end

        function e = normalize(raw, file)
            %normalize  A decoded JSON struct -> a normalized entry.
            %   Restores the shapes jsondecode changes (a one-element list
            %   comes back as a scalar, a list of one string as a char row,
            %   null as [], objects with different fields as a cell). A face
            %   that does not parse is left out and named in Problems.
            arguments
                raw
                file (1,1) string = ""
            end
            e = HardwareBank.emptyEntry();
            e.File = file;
            if ~isstruct(raw) || ~isscalar(raw)
                e.Problems = "Not a JSON object.";
                return
            end
            e.Kind = lower(str(raw, 'kind'));
            e.Manufacturer = str(raw, 'manufacturer');
            e.Name = str(raw, 'name');
            if e.Name == "" && file ~= ""
                [~, nm] = fileparts(file);
                e.Name = string(nm);
            end
            e.Channels = num(raw, 'channels');
            e.Model = str(raw, 'model');
            e.Notes = str(raw, 'notes');
            e.Source = str(raw, 'source');
            e.View = str(raw, 'view');
            if str(raw, 'schema') ~= HardwareBank.Schema
                e.Problems(end + 1, 1) = "Its schema is not " + HardwareBank.Schema + ".";
            end
            switch e.Kind
                case "connector"
                    e.Family = str(raw, 'family');
                    if e.Family == ""; e.Family = e.Name; end
                    e.Rows = num(raw, 'rows');
                    e.Cols = num(raw, 'cols');
                    g = HardwareBank.numList(field(raw, 'guides'));
                    if isfield(raw, 'guides') && isnumeric(raw.guides) && size(raw.guides, 2) == 2
                        g = double(raw.guides);
                    elseif mod(numel(g), 2) == 0
                        g = reshape(g, 2, [])';
                    else
                        e.Problems(end + 1, 1) = "guides must be a list of [row, column] pairs.";
                        g = zeros(0, 2);
                    end
                    e.Guides = g;
                    e.OneWay = logical(num(raw, 'oneWay', 0));
                    e.PitchMm = num(raw, 'pitchMm');
                case {"headstage", "package", "adaptor"}
                    e.ChannelLabel = str(raw, 'channelLabel');
                    if e.Kind == "headstage" && e.ChannelLabel == ""
                        e.ChannelLabel = "in%d";
                    end
                    e.HardwareChannels = HardwareBank.numList(field(raw, 'hardwareChannels'));
                    e.VerifiedHeadstages = HardwareBank.stringList(field(raw, 'verifiedHeadstages'));
                    faces = HardwareBank.structList(field(raw, 'faces'));
                    for f = 1:numel(faces)
                        fr = faces(f);
                        id = str(fr, 'id');
                        if id == ""; id = "main"; end
                        try
                            face = ChannelMap.faceFromRows(HardwareBank.stringList(field(fr, 'rows')), ...
                                Id=id, Gender=lower(str(fr, 'gender')), Connector=str(fr, 'connector'), ...
                                Rotation=num(fr, 'rotation', 0));
                            e.Faces(end + 1, 1) = face;
                        catch ME
                            e.Problems(end + 1, 1) = "Face " + id + ": " + string(ME.message);
                        end
                    end
                case "probe"
                    e.Shanks = num(raw, 'shanks');
                    e.Sites = HardwareBank.numList(field(raw, 'sites'));
                    e.X = HardwareBank.numList(field(raw, 'x'));
                    e.Y = HardwareBank.numList(field(raw, 'y'));
                    e.Shank = HardwareBank.numList(field(raw, 'shank'));
                    if isempty(e.Shank)
                        e.Shank = ones(size(e.Sites));
                    end
                    if isnan(e.Shanks) && ~isempty(e.Shank)
                        e.Shanks = numel(unique(e.Shank));
                    end
                    e.DefaultPackage = str(raw, 'defaultPackage');
                    e.Template = str(raw, 'template');
                    e.PitchUm = num(raw, 'pitchUm');
                    e.GeometrySource = str(raw, 'geometrySource');
                case "mapping"
                    e.Mapping = normalizeMapping(raw);
            end
            e.Id = HardwareBank.entryId(e.Kind, e.Manufacturer, e.Name);
        end

        function p = problems(e, connectors)
            %problems  What is wrong with a normalized entry, as a string column.
            %   CONNECTORS (connector entries) lets faces be checked against
            %   their connector's grid and guide posts.
            arguments
                e (1,1) struct
                connectors struct = struct([])
            end
            p = strings(0, 1);
            if ~any(e.Kind == HardwareBank.Kinds)
                p(end + 1) = "Unknown kind """ + e.Kind + """.";
                return
            end
            if e.Name == ""
                p(end + 1) = "It has no name.";
            end
            if ~any(e.Kind == ["connector" "mapping"]) && e.Manufacturer == ""
                p(end + 1) = "It has no manufacturer.";
            end
            if e.Kind ~= "mapping" && ~(isfinite(e.Channels) && e.Channels >= 1 && e.Channels == round(e.Channels))
                p(end + 1) = "channels must be a positive whole number.";
            end
            switch e.Kind
                case "connector"
                    if ~(e.Rows >= 1 && e.Cols >= 1)
                        p(end + 1) = "rows and cols must be positive.";
                    elseif ~isempty(e.Guides) && any(e.Guides(:, 1) < 1 | e.Guides(:, 1) > e.Rows | ...
                            e.Guides(:, 2) < 1 | e.Guides(:, 2) > e.Cols)
                        p(end + 1) = "A guide post lies outside the grid.";
                    end
                case {"headstage", "package", "adaptor"}
                    if isempty(e.Faces)
                        p(end + 1) = "It has no faces.";
                    end
                    want = "female";
                    if e.Kind == "package"; want = "male"; end
                    allNum = zeros(0, 1);
                    for f = 1:numel(e.Faces)
                        F = e.Faces(f);
                        if e.Kind ~= "adaptor" && F.Gender ~= want
                            p(end + 1) = sprintf("Face %s must be %s (it is ""%s"").", F.Id, want, F.Gender); %#ok<AGROW>
                        end
                        if sum(strs(e.Faces, "Id") == F.Id) > 1
                            p(end + 1) = "Two faces are called " + F.Id + "."; %#ok<AGROW>
                        end
                        c = connectors(strs(connectors, "Name") == F.Connector);
                        if F.Connector == ""
                            p(end + 1) = "Face " + F.Id + " names no connector."; %#ok<AGROW>
                        elseif ~isempty(connectors) && isempty(c)
                            p(end + 1) = "Face " + F.Id + ": unknown connector " + F.Connector + "."; %#ok<AGROW>
                        elseif ~isempty(c)
                            c = c(1);
                            if ~isequal(size(F.Cells), [c.Rows c.Cols])
                                p(end + 1) = sprintf("Face %s is %d x %d, its connector %s %d x %d.", F.Id, ...
                                    size(F.Cells, 1), size(F.Cells, 2), c.Name, c.Rows, c.Cols); %#ok<AGROW>
                            else
                                [gr, gc] = find(F.Cells == "GUIDE");
                                if ~isequal(sortrows([gr(:) gc(:)]), sortrows(reshape(c.Guides, [], 2)))
                                    p(end + 1) = "Face " + F.Id + ": its GUIDE cells are not where " + ...
                                        c.Name + " has guide posts."; %#ok<AGROW>
                                end
                            end
                        end
                        v = str2double(F.Cells(:));
                        allNum = [allNum; v(isfinite(v))]; %#ok<AGROW>
                    end
                    [u, ~, j] = unique(allNum);
                    if ~isempty(u)
                        twice = u(accumarray(j, 1) > 1);
                        if ~isempty(twice)
                            p(end + 1) = "Numbers used twice: " + strjoin(compose("%g", twice'), ", ") + ".";
                        end
                    end
                    if e.Kind == "package" && isfinite(e.Channels) && ~isequal(u(:)', 1:e.Channels)
                        p(end + 1) = sprintf("The sites must be exactly 1..%d (it has %d distinct numbers).", ...
                            e.Channels, numel(u));
                    end
                    if e.Kind == "headstage"
                        if numel(u) ~= e.Channels
                            p(end + 1) = sprintf("It has %d channels on its faces, channels says %d.", numel(u), e.Channels);
                        end
                        hc = e.HardwareChannels;
                        if numel(hc) == 2 && ~isempty(u) && (min(u) < hc(1) || max(u) > hc(2))
                            p(end + 1) = sprintf("Channels outside hardwareChannels %d..%d.", hc(1), hc(2));
                        end
                        try
                            sprintf(e.ChannelLabel, 0);
                        catch
                            p(end + 1) = "channelLabel must be a format such as in%d.";
                        end
                    end
                case "probe"
                    n = numel(e.Sites);
                    if n ~= e.Channels
                        p(end + 1) = sprintf("It has %d sites, channels says %d.", n, e.Channels);
                    end
                    if numel(e.X) ~= n || numel(e.Y) ~= n || numel(e.Shank) ~= n
                        p(end + 1) = "sites, x, y and shank must have the same length.";
                    end
                    if any(~isfinite([e.X; e.Y; e.Shank])) || any(~isfinite(e.Sites))
                        p(end + 1) = "sites, x, y and shank must all be numbers.";
                    end
                    if numel(unique(e.Sites)) ~= n || any(e.Sites < 1 | e.Sites ~= round(e.Sites))
                        p(end + 1) = "Site numbers must be distinct whole numbers from 1.";
                    end
                case "mapping"
                    m = e.Mapping;
                    if m.Package == ""
                        p(end + 1) = "It names no package.";
                    end
                    if isempty(m.Headstages)
                        p(end + 1) = "It names no headstage.";
                    end
                    if ~all(ismember(strs(m.Mates, "Orientation"), ChannelMap.Orientations))
                        p(end + 1) = "A mate's orientation is not reference or rotated.";
                    end
            end
            p = p(:);
        end

        function s = encode(e)
            %encode  A normalized entry -> the struct written to its JSON file.
            %   Lists are cells, so a list of one encodes as a list.
            s = struct();
            s.schema = char(HardwareBank.Schema);
            s.kind = char(e.Kind);
            s.manufacturer = char(e.Manufacturer);
            s.name = char(e.Name);
            if e.Model ~= ""
                s.model = char(e.Model);
            end
            if e.Kind ~= "mapping"
                s.channels = e.Channels;
            end
            switch e.Kind
                case "connector"
                    s.family = char(e.Family);
                    s.rows = e.Rows;
                    s.cols = e.Cols;
                    s.guides = num2cell(e.Guides, 2)';
                    s.oneWay = logical(e.OneWay);
                    s.pitchMm = e.PitchMm;
                case {"headstage", "package", "adaptor"}
                    if e.Kind == "headstage"
                        s.channelLabel = char(e.ChannelLabel);
                        s.hardwareChannels = num2cell(e.HardwareChannels(:));
                    end
                    s.view = char(e.View);
                    faces = cell(1, numel(e.Faces));
                    for f = 1:numel(e.Faces)
                        F = struct();
                        F.id = char(e.Faces(f).Id);
                        F.connector = char(e.Faces(f).Connector);
                        F.gender = char(e.Faces(f).Gender);
                        if e.Faces(f).Rotation ~= 0
                            F.rotation = e.Faces(f).Rotation;
                        end
                        F.rows = cellstr(e.Faces(f).Text(:));
                        faces{f} = F;
                    end
                    s.faces = faces;
                    if e.Kind == "package"
                        s.verifiedHeadstages = cellstr(e.VerifiedHeadstages(:))';
                    end
                case "probe"
                    s.shanks = e.Shanks;
                    s.sites = num2cell(e.Sites(:));
                    s.x = num2cell(e.X(:));
                    s.y = num2cell(e.Y(:));
                    s.shank = num2cell(e.Shank(:));
                    s.defaultPackage = char(e.DefaultPackage);
                    s.template = char(e.Template);
                    s.pitchUm = e.PitchUm;
                    s.geometrySource = char(e.GeometrySource);
                case "mapping"
                    m = e.Mapping;
                    s.channels = numel(m.Result.Site);
                    s.probe = char(m.Probe);
                    s.package = char(m.Package);
                    s.adaptors = cellstr(m.Adaptors(:))';
                    hs = cell(1, numel(m.Headstages));
                    for i = 1:numel(m.Headstages)
                        hs{i} = struct('id', char(m.Headstages(i).Id), 'channelOffset', m.Headstages(i).ChannelOffset);
                    end
                    s.headstages = hs;
                    ms = cell(1, numel(m.Mates));
                    for i = 1:numel(m.Mates)
                        ms{i} = struct('from', char(m.Mates(i).From), 'to', char(m.Mates(i).To), ...
                            'orientation', char(m.Mates(i).Orientation));
                    end
                    s.mates = ms;
                    rows = struct('mode', char(m.RowsMode), 'channelNumbers', [], 'dataset', char(m.Dataset));
                    if ~isempty(m.ChannelNumbers)
                        rows.channelNumbers = num2cell(m.ChannelNumbers(:));
                    end
                    s.rows = rows;
                    r = struct();
                    r.site = num2cell(m.Result.Site(:));
                    r.hardwareChannel = num2cell(m.Result.HardwareChannel(:));
                    r.recordingRow0 = num2cell(m.Result.RecordingRow0(:));
                    s.result = r;
                    s.problems = cellstr(m.SavedProblems(:))';
                    s.trust = char(m.Trust);
            end
            s.notes = char(e.Notes);
            s.source = char(e.Source);
        end

        function v = stringList(v)
            %stringList  Any decoded JSON list of strings -> a string column.
            if isempty(v)
                v = strings(0, 1);
            elseif ischar(v)
                v = string(v);
            elseif iscell(v)
                out = strings(numel(v), 1);
                for k = 1:numel(v)
                    if isempty(v{k})
                        out(k) = "";
                    else
                        out(k) = string(v{k});
                    end
                end
                v = out;
            else
                v = string(v(:));
            end
            v = v(:);
        end

        function v = numList(v)
            %numList  Any decoded JSON list of numbers -> a double column (null -> NaN).
            if isempty(v)
                v = zeros(0, 1);
            elseif iscell(v)
                out = NaN(numel(v), 1);
                for k = 1:numel(v)
                    if isnumeric(v{k}) && isscalar(v{k})
                        out(k) = double(v{k});
                    elseif islogical(v{k}) && isscalar(v{k})
                        out(k) = double(v{k});
                    elseif ischar(v{k}) || isstring(v{k})
                        out(k) = str2double(v{k});
                    end
                end
                v = out;
            elseif isnumeric(v) || islogical(v)
                v = double(v(:));
            else
                v = str2double(string(v(:)));
            end
        end

        function s = structList(v)
            %structList  Decoded JSON objects (struct array, or a cell of structs with different fields) -> a struct column.
            if isempty(v)
                s = struct([]);
                s = s(:);
            elseif isstruct(v)
                s = v(:);
            elseif iscell(v)
                names = strings(0, 1);
                for k = 1:numel(v)
                    if isstruct(v{k})
                        names = union(names, string(fieldnames(v{k})), 'stable');
                    end
                end
                s = repmat(cell2struct(cell(numel(names), 1), cellstr(names), 1), 0, 1);
                for k = 1:numel(v)
                    if ~isstruct(v{k}); continue; end
                    one = cell2struct(cell(numel(names), 1), cellstr(names), 1);
                    for n = string(fieldnames(v{k}))'
                        one.(n) = v{k}.(n);
                    end
                    s(end + 1, 1) = one; %#ok<AGROW>
                end
            else
                s = struct([]);
            end
        end
    end
end


function v = field(s, name)
%field  s.(name), or [] when it is missing.
if isfield(s, name)
    v = s.(name);
else
    v = [];
end
end


function v = str(s, name)
%str  A scalar string field ("" when missing or null).
v = field(s, name);
if isempty(v)
    v = "";
elseif iscell(v)
    v = strjoin(string(v), " ");
else
    v = string(v);
    if ~isscalar(v)
        v = strjoin(v(:)', " ");
    end
end
end


function v = num(s, name, default)
%num  A scalar numeric field (DEFAULT, NaN unless given, when missing or null).
if nargin < 3
    default = NaN;
end
v = field(s, name);
if isempty(v) || ~(isnumeric(v) || islogical(v))
    v = default;
else
    v = double(v(1));
end
end


function m = normalizeMapping(raw)
%normalizeMapping  The mapping fields of a decoded mapping (or sidecar "mapping") struct.
m = HardwareBank.emptyMapping();
m.Probe = str(raw, 'probe');
m.Package = str(raw, 'package');
m.Adaptors = HardwareBank.stringList(field(raw, 'adaptors'));
for h = HardwareBank.structList(field(raw, 'headstages'))'
    off = num(h, 'channelOffset', 0);
    m.Headstages(end + 1, 1) = struct('Id', str(h, 'id'), 'ChannelOffset', off);
end
for x = HardwareBank.structList(field(raw, 'mates'))'
    o = lower(str(x, 'orientation'));
    if o == ""; o = "reference"; end
    m.Mates(end + 1, 1) = struct('From', str(x, 'from'), 'To', str(x, 'to'), 'Orientation', o);
end
rows = field(raw, 'rows');
if isstruct(rows)
    m.RowsMode = str(rows, 'mode');
    m.ChannelNumbers = HardwareBank.numList(field(rows, 'channelNumbers'));
    m.Dataset = str(rows, 'dataset');
end
if m.RowsMode == ""
    m.RowsMode = "in-order";
end
r = field(raw, 'result');
if isstruct(r)
    m.Result.Site = HardwareBank.numList(field(r, 'site'));
    m.Result.HardwareChannel = HardwareBank.numList(field(r, 'hardwareChannel'));
    m.Result.RecordingRow0 = HardwareBank.numList(field(r, 'recordingRow0'));
end
m.SavedProblems = HardwareBank.stringList(field(raw, 'problems'));
m.Trust = str(raw, 'trust');
end


function p = mappingRefProblems(m, ids)
%mappingRefProblems  The devices a mapping names that the bank does not have.
p = strings(0, 1);
refs = [m.Probe; m.Package; strs(m.Headstages, "Id")'];
refs = refs(refs ~= "");
for r = refs'
    if ~any(ids == r)
        p(end + 1, 1) = "It names " + r + ", which is not in the bank."; %#ok<AGROW>
    end
end
end


function v = strs(S, name)
%strs  A string field of every element of a struct array, as a row (empty for none).
v = strings(1, numel(S));
for k = 1:numel(S)
    v(k) = S(k).(name);
end
end
