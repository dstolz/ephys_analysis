classdef ChannelMap
%ChannelMap  Probe site -> package pin -> headstage channel -> recording row.
%   ChannelMap holds the GUI-free logic of the channel mapper as static
%   methods. The hardware it works on (connectors, headstages, packages,
%   probe designs, saved mappings) comes from a HardwareBank, the JSON files
%   under pipeline/hardware; ChannelMapperApp is the window on top of both.
%
%   Connector faces
%     A face is a grid of cells describing a connector as seen looking into
%     its mating face, drawn exactly as the vendor diagram shows it:
%       "12"             a probe site number (package) or a 0-based hardware
%                        channel, in%d on Intan (headstage)
%       "GND"            ground (vendor G)
%       "REF", "REF1".."REF4"   reference (vendor R, R1..R4)
%       "PR"             probe-reference pin (NeuroNexus adaptors)
%       "NC"             pin present, not connected
%       "GUIDE"          guide post, no pin
%
%   Mating (male and female faces of one connector family, R rows x N columns)
%     reference   male (r, c) touches female (r, N+1-c)   (column mirror)
%     rotated     male (r, c) touches female (R+1-r, c)   (turned 180 degrees)
%   Both maps are involutions, so which face is "up" never matters.
%
%   Channel numbering
%     Hardware channel = the headstage cell + the headstage's ChannelOffset
%     (0-based, as EphysReader.ChannelNumbers). Recording row = index of the
%     hardware channel in the dataset's ChannelNumbers (0-based); without a
%     dataset, the rank among all the chain's headstage channels ascending.
%     Kilosort4's chanMap is the 0-based recording row of each site.
%
%   Methods (all static)
%     tokens = ChannelMap.parseRow(txt, cols)       one vendor row -> canonical tokens
%     face   = ChannelMap.faceFromRows(rows, ...)   rows -> face struct
%     M      = ChannelMap.mate(up, down, orientation)
%     p      = ChannelMap.mateProblems(M, ...)
%     pairs  = ChannelMap.defaultMates(upFaces, downFaces, orientation, downDevice)
%     R      = ChannelMap.resolve(chain)            the whole chain, per site
%     rows   = ChannelMap.recordingRows(hw, channelNumbers, allHw)
%     txt    = ChannelMap.toText(T, ...)            TSV / CSV / Markdown / MATLAB
%     s      = ChannelMap.pathText(R, site)
%     [probeFile, sidecar] = ChannelMap.exportKS4(R, probeFile, ...)
%     m      = ChannelMap.mappingStruct(R, ...)     the saved-mapping JSON struct
%     S      = ChannelMap.sitesFromTemplate(name, ...)
%     p      = ChannelMap.parseDesignName(name)
%     t      = ChannelMap.trust(chain)              "verified" | "rule-derived" | "unverified"
%     s      = ChannelMap.summary(chain)
%     n      = ChannelMap.pinName(cells, r, c)
%
%   The chain struct resolve takes
%     chain.probe          probe entry (HardwareBank) or [] (no geometry)
%     chain.package        package entry
%     chain.adaptors       {} (adaptors are not supported yet)
%     chain.headstages     struct array: Entry, ChannelOffset
%     chain.mates          struct array: From "package:<face>",
%                          To "headstage[i]:<face>", Orientation
%     chain.channelNumbers [] or the dataset's 0-based ChannelNumbers in
%                          recording order
%     chain.rowsMode       "in-order" | "dataset" | "custom" (for the summary)
%     chain.dataset        dataset name, when rowsMode is "dataset"
%
%   See also HardwareBank, ChannelMapperApp, writeProbeMap.

    properties (Constant)
        SidecarSchema = "ephys-channel-map/1"
        SidecarSuffix = ".chanmap.json"
        Orientations = ["reference" "rotated"]
    end

    methods (Static)
        % ------------------------------------------------------------ parsing
        function tokens = parseRow(txt, cols)
            %parseRow  One vendor row -> a row of canonical cell tokens.
            %   TOKENS = ChannelMap.parseRow("R1 18 27 ... G", 20) splits on
            %   white space, commas, semicolons or bars and canonicalises each
            %   token: a number stays a number ("09" -> "9", "in12" -> "12"),
            %   G -> GND, R -> REF, R1..R4 -> REF1..REF4, - x . NC -> NC,
            %   o () GUIDE -> GUIDE. COLS (NaN = any) is the expected count.
            %   Errors with ChannelMap:BadRow on a wrong count or an unknown
            %   token.
            arguments
                txt (1,1) string
                cols (1,1) double = NaN
            end
            raw = string(regexp(strtrim(txt), '[\s,;|]+', 'split'));
            raw(raw == "") = [];
            tokens = strings(1, numel(raw));
            for k = 1:numel(raw)
                t = ChannelMap.canonicalToken(raw(k));
                if ismissing(t)
                    error('ChannelMap:BadRow', 'Unknown token "%s" in row "%s".', raw(k), txt);
                end
                tokens(k) = t;
            end
            if ~isnan(cols) && numel(tokens) ~= cols
                error('ChannelMap:BadRow', 'The row has %d cells, expected %d: "%s".', ...
                    numel(tokens), cols, txt);
            end
        end

        function t = canonicalToken(t)
            %canonicalToken  One vendor token -> its canonical form (missing if unknown).
            u = upper(strtrim(string(t)));
            if ~isempty(regexp(u, '^\d+$', 'once'))
                t = string(str2double(u));
                return
            end
            if ~isempty(regexp(u, '^IN\d+$', 'once'))
                t = string(str2double(extractAfter(u, 2)));
                return
            end
            switch u
                case {"G", "GND", "GROUND"}
                    t = "GND";
                case {"R", "REF"}
                    t = "REF";
                case {"R1", "R2", "R3", "R4"}
                    t = "REF" + extractAfter(u, 1);
                case {"REF1", "REF2", "REF3", "REF4", "PR"}
                    t = u;
                case {"-", "X", "NC", ".", char(183), char(8211)}
                    t = "NC";
                case {"O", "GUIDE", "()"}
                    t = "GUIDE";
                otherwise
                    t = string(missing);
            end
        end

        function c = cellClass(v)
            %cellClass  "signal" | "GND" | "REF" | "NC" | "GUIDE" for each cell token.
            v = string(v);
            c = repmat("signal", size(v));
            c(v == "GND") = "GND";
            c(startsWith(v, "REF") | v == "PR") = "REF";
            c(v == "NC") = "NC";
            c(v == "GUIDE") = "GUIDE";
        end

        function face = faceFromRows(rows, opts)
            %faceFromRows  Rows of vendor notation -> a face struct.
            %   FACE = ChannelMap.faceFromRows(ROWS, Id=, Gender=, Connector=,
            %   Size=[R C], Guides=[r c; ...], OneWay=) parses each row with
            %   parseRow. With Size, the face must have R rows of C cells; a
            %   row that leaves out its guide posts (C minus the guides on
            %   that row) gets GUIDE cells put back where Guides says.
            %   FACE has fields Id, Connector, Gender, Text (canonical rows),
            %   Cells (R x C string), OneWay, Rotation.
            arguments
                rows string
                opts.Id (1,1) string = "main"
                opts.Gender (1,1) string = ""
                opts.Connector (1,1) string = ""
                opts.Size double = []
                opts.Guides (:,2) double = zeros(0, 2)
                opts.OneWay (1,1) logical = false
                opts.Rotation (1,1) double = 0
            end
            rows = rows(:);
            rows(strtrim(rows) == "") = [];
            if isempty(rows)
                error('ChannelMap:BadFace', 'Face %s has no rows.', opts.Id);
            end
            nR = numel(rows);
            if ~isempty(opts.Size)
                if nR ~= opts.Size(1)
                    error('ChannelMap:BadFace', 'Face %s has %d rows, its connector %d.', ...
                        opts.Id, nR, opts.Size(1));
                end
                nC = opts.Size(2);
            else
                nC = numel(ChannelMap.parseRow(rows(1)));
            end
            cells = strings(nR, nC);
            for r = 1:nR
                tok = ChannelMap.parseRow(rows(r));
                g = opts.Guides(opts.Guides(:, 1) == r, 2);
                if numel(tok) == nC
                    cells(r, :) = tok;
                elseif ~isempty(g) && numel(tok) == nC - numel(g)
                    full = strings(1, nC);
                    full(g) = "GUIDE";
                    full(setdiff(1:nC, g)) = tok;
                    cells(r, :) = full;
                else
                    error('ChannelMap:BadRow', 'Face %s row %d has %d cells, expected %d: "%s".', ...
                        opts.Id, r, numel(tok), nC, rows(r));
                end
            end
            face = ChannelMap.makeFace(opts.Id, opts.Connector, opts.Gender, cells, opts.OneWay, opts.Rotation);
        end

        function face = makeFace(id, connector, gender, cells, oneWay, rotation)
            %makeFace  The face struct (fields in one fixed order, so faces concatenate).
            if nargin < 5; oneWay = false; end
            if nargin < 6; rotation = 0; end
            text = strings(size(cells, 1), 1);
            for r = 1:size(cells, 1)
                text(r) = strjoin(cells(r, :), " ");
            end
            face = struct('Id', string(id), 'Connector', string(connector), 'Gender', string(gender), ...
                'Text', text, 'Cells', cells, 'OneWay', logical(oneWay), 'Rotation', double(rotation));
        end

        function f = emptyFaces()
            %emptyFaces  A 0x1 face struct array.
            f = ChannelMap.makeFace("", "", "", strings(0, 0));
            f = f([]);
            f = f(:);
        end

        % ------------------------------------------------------------- mating
        function M = mate(up, down, orientation)
            %mate  Which cell of DOWN each cell of UP touches.
            %   M = ChannelMap.mate(UP, DOWN, ORIENTATION) returns a table with
            %   one row per UP cell (row-major): UpRow UpCol UpValue DownRow
            %   DownCol DownValue. Errors ChannelMap:FamilyMismatch (different
            %   connectors), ChannelMap:SizeMismatch, ChannelMap:GenderMismatch
            %   (two males or two females).
            arguments
                up (1,1) struct
                down (1,1) struct
                orientation (1,1) string {mustBeMember(orientation, ["reference" "rotated"])} = "reference"
            end
            if up.Connector ~= "" && down.Connector ~= "" && up.Connector ~= down.Connector
                error('ChannelMap:FamilyMismatch', '%s (%s) does not mate with %s (%s).', ...
                    up.Id, up.Connector, down.Id, down.Connector);
            end
            [nR, nC] = size(up.Cells);
            if ~isequal(size(down.Cells), [nR nC])
                error('ChannelMap:SizeMismatch', 'Face %s is %d x %d, face %s %d x %d.', ...
                    up.Id, nR, nC, down.Id, size(down.Cells, 1), size(down.Cells, 2));
            end
            if up.Gender ~= "" && up.Gender == down.Gender
                error('ChannelMap:GenderMismatch', 'Faces %s and %s are both %s.', up.Id, down.Id, up.Gender);
            end
            ur = repelem((1:nR)', nC);
            uc = repmat((1:nC)', nR, 1);
            if orientation == "reference"
                dr = ur;
                dc = nC + 1 - uc;
            else
                dr = nR + 1 - ur;
                dc = uc;
            end
            uv = up.Cells(sub2ind([nR nC], ur, uc));
            dv = down.Cells(sub2ind([nR nC], dr, dc));
            M = table(ur, uc, uv(:), dr, dc, dv(:), 'VariableNames', ...
                {'UpRow', 'UpCol', 'UpValue', 'DownRow', 'DownCol', 'DownValue'});
        end

        function p = mateProblems(M, opts)
            %mateProblems  What is wrong with one mate, as a string column.
            %   P = ChannelMap.mateProblems(M, OneWay=, Orientation=, Label=,
            %   UpCells=, DownCells=) lists a guide post meeting a pin, GND
            %   meeting anything but GND, a reference meeting anything but a
            %   reference, and a rotated mate of a connector that fits one way
            %   only. A pin meeting NC is not a problem here (resolve flags
            %   the site). UpCells / DownCells (the faces' cells) name pins as
            %   "top:17" instead of "(1,18)".
            arguments
                M table
                opts.OneWay (1,1) logical = false
                opts.Orientation (1,1) string = "reference"
                opts.Label (1,1) string = ""
                opts.UpCells string = strings(0, 0)
                opts.DownCells string = strings(0, 0)
            end
            p = strings(0, 1);
            pre = "";
            if opts.Label ~= ""
                pre = opts.Label + ": ";
            end
            if opts.OneWay && opts.Orientation == "rotated"
                p(end + 1, 1) = pre + "this connector mates one way only; the rotated orientation does not fit.";
            end
            a = ChannelMap.cellClass(M.UpValue);
            b = ChannelMap.cellClass(M.DownValue);
            for k = 1:height(M)
                bad = false;
                if a(k) == "GUIDE" || b(k) == "GUIDE"
                    bad = a(k) ~= b(k);
                elseif a(k) == "NC" || b(k) == "NC"
                    bad = false;
                elseif a(k) == "GND" || b(k) == "GND"
                    bad = a(k) ~= b(k);
                elseif a(k) == "REF" || b(k) == "REF"
                    bad = a(k) ~= b(k);
                end
                if bad
                    p(end + 1, 1) = pre + sprintf("%s at %s meets %s at %s.", ...
                        M.UpValue(k), cellNameOf(opts.UpCells, M.UpRow(k), M.UpCol(k)), ...
                        M.DownValue(k), cellNameOf(opts.DownCells, M.DownRow(k), M.DownCol(k))); %#ok<AGROW>
                end
            end
        end

        function n = pinName(cells, r, c)
            %pinName  "top:17": the row's name and the pin's place along it.
            %   Rows of a two-row face are "top" and "bottom" (as drawn), of a
            %   one-row face "row", otherwise "r3". Pins are counted from the
            %   left of the drawing, guide posts left out; a guide post is
            %   "top:guide".
            nR = size(cells, 1);
            if nR == 1
                rn = "row";
            elseif nR == 2
                names = ["top" "bottom"];
                rn = names(r);
            else
                rn = "r" + r;
            end
            if cells(r, c) == "GUIDE"
                n = rn + ":guide";
            else
                n = rn + ":" + sum(cells(r, 1:c) ~= "GUIDE");
            end
        end

        function pairs = defaultMates(upFaces, downFaces, orientation, downDevice)
            %defaultMates  Pair up faces with down faces of the same connector.
            %   PAIRS = ChannelMap.defaultMates(UP, DOWN, ORIENTATION, DEVICE)
            %   returns an n x 2 [upIndex downIndex] list. Each up face, in
            %   order, takes the first unused down face of its connector.
            %   Rotated turns each device (DEVICE(k) = the device of DOWN(k);
            %   default all one) around, so a two-connector package on a
            %   two-connector headstage pairs top with bottom and bottom with
            %   top; separate headstages keep their order.
            arguments
                upFaces struct
                downFaces struct
                orientation (1,1) string = "reference"
                downDevice double = []
            end
            if isempty(downDevice)
                downDevice = ones(1, numel(downFaces));
            end
            order = 1:numel(downFaces);
            if orientation == "rotated"
                order = [];
                for d = unique(downDevice(:)', 'stable')
                    order = [order, fliplr(find(downDevice == d))]; %#ok<AGROW>
                end
            end
            used = false(1, numel(downFaces));
            pairs = zeros(0, 2);
            for i = 1:numel(upFaces)
                for j = order
                    if ~used(j) && upFaces(i).Connector == downFaces(j).Connector
                        used(j) = true;
                        pairs(end + 1, :) = [i j]; %#ok<AGROW>
                        break
                    end
                end
            end
        end

        % ---------------------------------------------------------- resolving
        function R = resolve(chain)
            %resolve  Follow every site of the chain to its recording row.
            %   R = ChannelMap.resolve(CHAIN) returns a struct:
            %     Table     one row per site: Site Shank X Y PackageConnector
            %               PackagePin HeadstageConnector HeadstagePin
            %               HeadstageChannel HardwareChannel RecordingRow0
            %               RecordingRow1 Flag. A site that does not reach a
            %               recorded channel has NaN rows and a Flag ("GND",
            %               "REF", "NC", "guide", "unmated", "not on package",
            %               "not recorded").
            %     Path      per site: Site, PkgFace, PkgCell [r c], Mate,
            %               HsIndex, HsFace, HsCell [r c]
            %     Mates     per mate: From, To, Orientation, PkgFace, HsIndex,
            %               HsFace, Map (see mate), Problems
            %     Problems  string column (empty = fine)
            %     NChan     recorded channels (the dataset's, or the chain's
            %               headstage channels)
            %     AllHardware  every hardware channel of the chain's headstages
            %     Trust, Summary, Chain
            chain = ChannelMap.fillChain(chain);
            pkg = chain.package;
            problems = strings(0, 1);
            if isempty(pkg)
                error('ChannelMap:NoPackage', 'The chain has no package.');
            end

            % --- sites ---
            if ~isempty(chain.probe)
                pr = chain.probe;
                site = double(pr.Sites(:));
                X = double(pr.X(:));
                Y = double(pr.Y(:));
                Shank = double(pr.Shank(:));
                if numel(Shank) ~= numel(site)
                    Shank = ones(size(site));
                end
            else
                site = (1:pkg.Channels)';
                X = NaN(size(site));
                Y = NaN(size(site));
                Shank = NaN(size(site));
            end
            n = numel(site);

            % --- headstage channels ---
            nH = numel(chain.headstages);
            hwAll = zeros(0, 1);
            for i = 1:nH
                e = chain.headstages(i).Entry;
                off = chain.headstages(i).ChannelOffset;
                for f = 1:numel(e.Faces)
                    v = str2double(e.Faces(f).Cells(:));
                    hwAll = [hwAll; v(isfinite(v)) + off]; %#ok<AGROW>
                end
            end
            [u, dup] = uniqueWithRepeats(hwAll);
            if ~isempty(dup)
                problems(end + 1, 1) = sprintf("Two headstages share hardware channels (%s); give the second one a channel offset.", ...
                    compactList(dup));
            end
            allHw = u;

            % --- mates ---
            mates = struct('From', {}, 'To', {}, 'Orientation', {}, 'PkgFace', {}, ...
                'HsIndex', {}, 'HsFace', {}, 'Map', {}, 'Problems', {});
            pkgIds = strs(pkg.Faces, "Id");
            for m = 1:numel(chain.mates)
                cm = chain.mates(m);
                mi = struct('From', string(cm.From), 'To', string(cm.To), ...
                    'Orientation', string(cm.Orientation), 'PkgFace', NaN, 'HsIndex', NaN, ...
                    'HsFace', NaN, 'Map', table(), 'Problems', strings(0, 1));
                fromFace = extractAfter(mi.From, "package:");
                fi = find(pkgIds == fromFace, 1);
                tok = regexp(mi.To, '^headstage\[(\d+)\]:(.+)$', 'tokens', 'once');
                if ismissing(fromFace) || isempty(fi)
                    mi.Problems = "Mate " + m + ": " + mi.From + " is not a face of " + pkg.Name + ".";
                elseif isempty(tok) || str2double(tok(1)) < 1 || str2double(tok(1)) > nH
                    mi.Problems = "Mate " + m + ": " + mi.To + " is not a headstage face of this chain.";
                else
                    hi = str2double(tok(1));
                    he = chain.headstages(hi).Entry;
                    hf = find(strs(he.Faces, "Id") == string(tok(2)), 1);
                    if isempty(hf)
                        mi.Problems = "Mate " + m + ": " + he.Name + " has no face " + tok(2) + ".";
                    else
                        mi.PkgFace = fi;
                        mi.HsIndex = hi;
                        mi.HsFace = hf;
                        up = pkg.Faces(fi);
                        dn = he.Faces(hf);
                        label = pkg.Name + " " + up.Id + " / " + hsLabelOf(chain, hi) + " " + dn.Id;
                        try
                            mi.Map = ChannelMap.mate(up, dn, mi.Orientation);
                            mi.Problems = ChannelMap.mateProblems(mi.Map, OneWay=up.OneWay || dn.OneWay, ...
                                Orientation=mi.Orientation, Label=label, UpCells=up.Cells, DownCells=dn.Cells);
                        catch ME
                            mi.Problems = label + ": " + string(ME.message);
                        end
                    end
                end
                mates(end + 1) = mi; %#ok<AGROW>
                problems = [problems; mi.Problems]; %#ok<AGROW>
            end
            usedPkg = usedPkgOf(mates);
            [~, twice] = uniqueWithRepeats(usedPkg(isfinite(usedPkg)));
            for k = twice(:)'
                problems(end + 1, 1) = pkg.Name + " " + pkg.Faces(k).Id + " is mated twice."; %#ok<AGROW>
            end
            hsKeys = zeros(0, 1);
            for m = 1:numel(mates)
                if isfinite(mates(m).HsIndex)
                    hsKeys(end + 1, 1) = mates(m).HsIndex * 1000 + mates(m).HsFace; %#ok<AGROW>
                end
            end
            [~, twice] = uniqueWithRepeats(hsKeys);
            for k = twice(:)'
                hi = floor(k / 1000);
                problems(end + 1, 1) = hsLabelOf(chain, hi) + " " + ...
                    chain.headstages(hi).Entry.Faces(mod(k, 1000)).Id + " is mated twice."; %#ok<AGROW>
            end

            % --- package cell of each site ---
            pkgNum = cell(1, numel(pkg.Faces));
            for f = 1:numel(pkg.Faces)
                pkgNum{f} = str2double(pkg.Faces(f).Cells);
            end

            % --- per site ---
            PackageConnector = strings(n, 1);
            PackagePin = strings(n, 1);
            HeadstageConnector = strings(n, 1);
            HeadstagePin = strings(n, 1);
            HeadstageChannel = strings(n, 1);
            HardwareChannel = NaN(n, 1);
            RecordingRow0 = NaN(n, 1);
            Flag = strings(n, 1);
            hop = repmat(struct('Site', NaN, 'PkgFace', NaN, 'PkgCell', [NaN NaN], 'Mate', NaN, ...
                'HsIndex', NaN, 'HsFace', NaN, 'HsCell', [NaN NaN]), n, 1);
            for k = 1:n
                s = site(k);
                hop(k).Site = s;
                fk = NaN; rc = [];
                for f = 1:numel(pkgNum)
                    [r, c] = find(pkgNum{f} == s, 1);
                    if ~isempty(r)
                        fk = f; rc = [r c];
                        break
                    end
                end
                if isnan(fk)
                    Flag(k) = "not on package";
                    continue
                end
                hop(k).PkgFace = fk;
                hop(k).PkgCell = rc;
                PackageConnector(k) = pkg.Faces(fk).Id;
                PackagePin(k) = ChannelMap.pinName(pkg.Faces(fk).Cells, rc(1), rc(2));
                m = find(usedPkgOf(mates) == fk, 1);
                if isempty(m) || isempty(mates(m).Map) || width(mates(m).Map) == 0
                    Flag(k) = "unmated";
                    continue
                end
                Mm = mates(m).Map;
                row = find(Mm.UpRow == rc(1) & Mm.UpCol == rc(2), 1);
                hi = mates(m).HsIndex;
                he = chain.headstages(hi).Entry;
                hf = he.Faces(mates(m).HsFace);
                dv = Mm.DownValue(row);
                hop(k).Mate = m;
                hop(k).HsIndex = hi;
                hop(k).HsFace = mates(m).HsFace;
                hop(k).HsCell = [Mm.DownRow(row) Mm.DownCol(row)];
                HeadstageConnector(k) = hsLabelOf(chain, hi) + " " + hf.Id;
                HeadstagePin(k) = ChannelMap.pinName(hf.Cells, Mm.DownRow(row), Mm.DownCol(row));
                cls = ChannelMap.cellClass(dv);
                if cls ~= "signal"
                    if cls == "GUIDE"
                        Flag(k) = "guide";
                    else
                        Flag(k) = cls;
                    end
                    continue
                end
                hc = str2double(dv);
                label = he.ChannelLabel;
                if label == ""; label = "in%d"; end
                HeadstageChannel(k) = sprintf(label, hc);
                HardwareChannel(k) = hc + chain.headstages(hi).ChannelOffset;
                RecordingRow0(k) = ChannelMap.recordingRows(HardwareChannel(k), chain.channelNumbers, allHw);
                if isnan(RecordingRow0(k))
                    Flag(k) = "not recorded";
                end
            end
            RecordingRow1 = RecordingRow0 + 1;

            % --- problems per site ---
            for k = find(Flag ~= "")'
                switch Flag(k)
                    case "not on package"
                        problems(end + 1, 1) = sprintf("Site %g is not on %s.", site(k), pkg.Name); %#ok<AGROW>
                    case "unmated"
                        problems(end + 1, 1) = sprintf("Site %g: %s %s is not mated to a headstage.", ...
                            site(k), pkg.Name, PackageConnector(k)); %#ok<AGROW>
                    case "not recorded"
                        % the dataset left the channel out: shown in the table, not a wiring problem
                    otherwise
                        problems(end + 1, 1) = sprintf("Site %g lands on %s (%s).", ...
                            site(k), Flag(k), HeadstageConnector(k) + " " + HeadstagePin(k)); %#ok<AGROW>
                end
            end
            [~, twice] = uniqueWithRepeats(HardwareChannel(isfinite(HardwareChannel)));
            for h = twice(:)'
                problems(end + 1, 1) = sprintf("Sites %s all land on hardware channel %d.", ...
                    compactList(site(HardwareChannel == h)), h); %#ok<AGROW>
            end

            R = struct();
            R.Table = table(site, Shank, X, Y, PackageConnector, PackagePin, HeadstageConnector, ...
                HeadstagePin, HeadstageChannel, HardwareChannel, RecordingRow0, RecordingRow1, Flag, ...
                'VariableNames', {'Site', 'Shank', 'X', 'Y', 'PackageConnector', 'PackagePin', ...
                'HeadstageConnector', 'HeadstagePin', 'HeadstageChannel', 'HardwareChannel', ...
                'RecordingRow0', 'RecordingRow1', 'Flag'});
            R.Path = hop;
            R.Mates = mates;
            R.Problems = unique(problems, 'stable');
            if isempty(chain.channelNumbers)
                R.NChan = numel(allHw);
            else
                R.NChan = numel(chain.channelNumbers);
            end
            R.AllHardware = allHw;
            R.Trust = ChannelMap.trust(chain);
            R.Summary = ChannelMap.summary(chain);
            R.Chain = chain;
        end

        function chain = fillChain(chain)
            %fillChain  Defaults for the chain fields resolve reads.
            defaults = struct('probe', [], 'package', [], 'adaptors', {{}}, ...
                'headstages', struct('Entry', {}, 'ChannelOffset', {}), ...
                'mates', struct('From', {}, 'To', {}, 'Orientation', {}), ...
                'channelNumbers', [], 'rowsMode', "in-order", 'dataset', "");
            for f = string(fieldnames(defaults))'
                if ~isfield(chain, f)
                    chain.(f) = defaults.(f);
                end
            end
            chain.channelNumbers = double(chain.channelNumbers(:))';
            chain.rowsMode = string(chain.rowsMode);
            chain.dataset = string(chain.dataset);
        end

        function rows = recordingRows(hw, channelNumbers, allHw)
            %recordingRows  0-based recording row of each hardware channel.
            %   ROWS = ChannelMap.recordingRows(HW, CHANNELNUMBERS) is the index
            %   of each HW in CHANNELNUMBERS minus one, NaN when absent. With
            %   CHANNELNUMBERS empty, ROWS is the rank of HW among ALLHW (all
            %   the chain's headstage channels) ascending: the headstages'
            %   channels recorded in order.
            arguments
                hw double
                channelNumbers double = []
                allHw double = []
            end
            if isempty(channelNumbers)
                ref = unique(allHw(:))';
            else
                ref = channelNumbers(:)';
            end
            rows = NaN(size(hw));
            for k = 1:numel(hw)
                i = find(ref == hw(k), 1);
                if ~isempty(i)
                    rows(k) = i - 1;
                end
            end
        end

        % -------------------------------------------------------------- trust
        function t = trust(chain)
            %trust  How far the chain can be believed.
            %   "verified"      one headstage the package lists under
            %                   verifiedHeadstages, every mate reference and
            %                   face to same-named face (checked against a
            %                   recording or probeinterface)
            %   "rule-derived"  every mate in the reference orientation
            %   "unverified"    a rotated mate or an adaptor
            chain = ChannelMap.fillChain(chain);
            if ~isempty(chain.adaptors)
                t = "unverified";
                return
            end
            ori = strings(1, numel(chain.mates));
            same = true;
            for m = 1:numel(chain.mates)
                ori(m) = string(chain.mates(m).Orientation);
                a = extractAfter(string(chain.mates(m).From), ":");
                b = extractAfter(string(chain.mates(m).To), ":");
                same = same && ~ismissing(a) && ~ismissing(b) && a == b;
            end
            if isempty(chain.mates) || any(ori ~= "reference")
                t = "unverified";
                return
            end
            t = "rule-derived";
            if isscalar(chain.headstages) && ~isempty(chain.package) && same && ...
                    isfield(chain.package, 'VerifiedHeadstages') && ...
                    any(chain.package.VerifiedHeadstages == chain.headstages(1).Entry.Id) && ...
                    numel(chain.mates) == numel(chain.package.Faces)
                t = "verified";
            end
        end

        function s = summary(chain)
            %summary  One line naming the chain: probe on package -> headstages (mates); rows.
            chain = ChannelMap.fillChain(chain);
            parts = strings(0, 1);
            if ~isempty(chain.probe)
                parts(end + 1) = chain.probe.Id + " on";
            end
            if ~isempty(chain.package)
                parts(end + 1) = chain.package.Id;
            end
            hs = strings(1, numel(chain.headstages));
            for i = 1:numel(chain.headstages)
                hs(i) = chain.headstages(i).Entry.Id;
                if chain.headstages(i).ChannelOffset ~= 0
                    hs(i) = hs(i) + sprintf(" (+%d)", chain.headstages(i).ChannelOffset);
                end
            end
            parts(end + 1) = char(8594) + " " + strjoin(hs, " + ");
            ms = strings(1, numel(chain.mates));
            for m = 1:numel(chain.mates)
                ms(m) = extractAfter(string(chain.mates(m).From), "package:") + char(8594) + ...
                    string(chain.mates(m).To) + " " + string(chain.mates(m).Orientation);
            end
            s = strjoin(parts, " ");
            if ~isempty(ms)
                s = s + " (" + strjoin(ms, ", ") + ")";
            end
            switch chain.rowsMode
                case "dataset"
                    s = s + "; rows: dataset " + chain.dataset + sprintf(" (%d channels)", numel(chain.channelNumbers));
                case "custom"
                    s = s + sprintf("; rows: custom list of %d channels", numel(chain.channelNumbers));
                otherwise
                    s = s + "; rows: headstage channels in order";
            end
        end

        % --------------------------------------------------------------- text
        function txt = toText(T, opts)
            %toText  The result table as text for the clipboard or a file.
            %   TXT = ChannelMap.toText(T, Format=, SortBy=, Columns=)
            %     Format  "tsv" (default; pastes into Excel) | "csv" |
            %             "markdown" | "matlab" (site and chanMap vectors)
            %     SortBy  "site" (default) | "channel" (recording row) |
            %             "depth" (shank, then from the tip up)
            %   NaN is written as an empty cell ("NaN" in "matlab").
            arguments
                T table
                opts.Format (1,1) string {mustBeMember(opts.Format, ["tsv" "csv" "markdown" "matlab"])} = "tsv"
                opts.SortBy (1,1) string {mustBeMember(opts.SortBy, ["site" "channel" "depth"])} = "site"
                opts.Columns string = string(T.Properties.VariableNames)
            end
            T = ChannelMap.sortTable(T, opts.SortBy);
            if opts.Format == "matlab"
                txt = sprintf("site    = [%s];\nchanMap = [%s];   %% 0-based recording rows of the sites above (NaN = not recorded)\n", ...
                    strjoin(compose("%g", T.Site'), " "), strjoin(compose("%g", T.RecordingRow0'), " "));
                return
            end
            cols = opts.Columns(ismember(opts.Columns, string(T.Properties.VariableNames)));
            C = strings(height(T), numel(cols));
            for j = 1:numel(cols)
                v = T.(cols(j));
                if isnumeric(v)
                    s = compose("%.10g", v);
                    s(isnan(v)) = "";
                else
                    s = string(v);
                    s(ismissing(s)) = "";
                end
                C(:, j) = s;
            end
            switch opts.Format
                case "tsv"
                    lines = [strjoin(cols, char(9)); join(C, char(9), 2)];
                case "csv"
                    lines = [strjoin(csvQuote(cols), ","); join(csvQuote(C), ",", 2)];
                case "markdown"
                    lines = ["| " + strjoin(cols, " | ") + " |"; ...
                        "| " + strjoin(repmat("---", 1, numel(cols)), " | ") + " |"; ...
                        "| " + join(replace(C, "|", "\|"), " | ", 2) + " |"];
            end
            txt = strjoin(lines(:)', newline) + newline;
        end

        function [T, i] = sortTable(T, by)
            %sortTable  Rows by site, recording row (NaN last) or shank then tip-up.
            %   [T, I] = ChannelMap.sortTable(T, BY) also returns the order I.
            if height(T) == 0
                i = zeros(0, 1);
                return
            end
            switch by
                case "channel"
                    [~, i] = sortrows([isnan(T.RecordingRow0), T.RecordingRow0, T.Site]);
                case "depth"
                    [~, i] = sortrows([T.Shank, T.Y, T.Site]);
                otherwise
                    [~, i] = sort(T.Site);
            end
            T = T(i, :);
        end

        function s = pathText(R, site)
            %pathText  One site's way through the chain, as a line of text.
            %   "Site 18 -> H32 top:2 -> RHD2132-32ch top:17 -> in8 -> hardware 8
            %   -> row 9 (1-based) / 8 (0-based)", with arrows. A device with
            %   several connectors names the connector after the pin
            %   ("H64LP bottom:10 (top)"), several headstages their number
            %   ("RHD2132-32ch #2 top:17").
            k = find(R.Table.Site == site, 1);
            arrow = " " + char(8594) + " ";
            if isempty(k)
                s = sprintf("Site %g is not a site of this probe.", site);
                return
            end
            t = R.Table(k, :);
            p = R.Path(k);
            pkg = R.Chain.package;
            s = "Site " + site;
            if t.PackagePin ~= ""
                s = s + arrow + pkg.Name + " " + t.PackagePin;
                if numel(pkg.Faces) > 1
                    s = s + " (" + t.PackageConnector + ")";
                end
            end
            if t.HeadstagePin ~= ""
                he = R.Chain.headstages(p.HsIndex).Entry;
                name = he.Name;
                if numel(R.Chain.headstages) > 1
                    name = name + " #" + p.HsIndex;
                end
                s = s + arrow + name + " " + t.HeadstagePin;
                if numel(he.Faces) > 1
                    s = s + " (" + he.Faces(p.HsFace).Id + ")";
                end
            end
            if t.HeadstageChannel ~= ""
                s = s + arrow + t.HeadstageChannel;
            end
            if isfinite(t.HardwareChannel)
                s = s + arrow + "hardware " + t.HardwareChannel;
            end
            if isfinite(t.RecordingRow0)
                s = s + arrow + sprintf("row %d (1-based) / %d (0-based)", t.RecordingRow1, t.RecordingRow0);
            end
            switch t.Flag
                case ""
                case "not recorded"
                    s = s + arrow + "not recorded by the dataset";
                case {"GND", "REF"}
                    s = s + arrow + t.Flag + " (not a recording channel)";
                case "NC"
                    s = s + arrow + "not connected";
                otherwise
                    s = s + arrow + t.Flag;
            end
        end

        % ------------------------------------------------------------- export
        function [probeFile, sidecar] = exportKS4(R, probeFile, opts)
            %exportKS4  Write the resolved chain as a Kilosort4 probe .json.
            %   [PROBEFILE, SIDECAR] = ChannelMap.exportKS4(R, PROBEFILE, ...)
            %   writes chanMap = RecordingRow0, xc = X, yc = Y, kcoords =
            %   Shank, n_chan = max(sites, max(chanMap)+1, R.NChan, NChan) and
            %   notes (the chain summary and its trust) through writeProbeMap,
            %   plus the sidecar <probe>.chanmap.json that records the chain.
            %   Options
            %     DropUnmapped  true (default): sites without a recording row
            %                   are left out and named in the notes; false:
            %                   error ChannelMap:Unmapped
            %     NChan         the recording's channel count (NaN = R.NChan)
            %     Notes         text added to the notes
            %     Sidecar       write the sidecar (default true)
            %     Mapping       the mapping struct for the sidecar (default
            %                   ChannelMap.mappingStruct(R))
            %   Errors ChannelMap:NoGeometry (no probe design),
            %   ChannelMap:Unmapped, ChannelMap:DuplicateRows.
            arguments
                R (1,1) struct
                probeFile (1,1) string
                opts.DropUnmapped (1,1) logical = true
                opts.NChan (1,1) double = NaN
                opts.Notes (1,1) string = ""
                opts.Sidecar (1,1) logical = true
                opts.Mapping = []
            end
            T = R.Table;
            if all(isnan(T.X))
                error('ChannelMap:NoGeometry', 'Choose a probe design first: the probe file needs site positions.');
            end
            bad = isnan(T.RecordingRow0) | isnan(T.X) | isnan(T.Y);
            if any(bad) && ~opts.DropUnmapped
                error('ChannelMap:Unmapped', 'Sites without a recording row: %s.', ...
                    strjoin(compose("%g (%s)", T.Site(bad), T.Flag(bad)), ", "));
            end
            keep = ~bad;
            if ~any(keep)
                error('ChannelMap:Unmapped', 'No site reaches a recording row.');
            end
            rows = T.RecordingRow0(keep);
            if numel(unique(rows)) ~= numel(rows)
                error('ChannelMap:DuplicateRows', 'Two or more sites land on the same recording row; fix the chain first.');
            end
            notes = R.Summary + "; " + R.Trust + "; written by ChannelMapperApp";
            if any(bad)
                notes = notes + "; left out: sites " + strjoin(compose("%g (%s)", T.Site(bad), T.Flag(bad)), ", ");
            end
            if opts.Notes ~= ""
                notes = opts.Notes + " | " + notes;
            end
            shank = T.Shank(keep);
            shank(isnan(shank)) = 1;
            ks4 = struct();
            ks4.notes = char(notes);
            ks4.chanMap = rows;
            ks4.xc = T.X(keep);
            ks4.yc = T.Y(keep);
            ks4.kcoords = shank;
            ks4.n_chan = max([numel(rows), max(rows) + 1, R.NChan, opts.NChan], [], 'omitnan');
            writeProbeMap(probeFile, ks4);

            sidecar = "";
            if opts.Sidecar
                sidecar = ChannelMap.sidecarFile(probeFile);
                mapping = opts.Mapping;
                if isempty(mapping)
                    mapping = ChannelMap.mappingStruct(R);
                end
                [~, nm, ext] = fileparts(probeFile);
                sc = struct();
                sc.schema = char(ChannelMap.SidecarSchema);
                sc.probeFile = char(nm + ext);
                sc.mapping = mapping;
                sc.result = ChannelMap.resultStruct(T);
                sc.trust = char(R.Trust);
                sc.written = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
                sc.app = char("ChannelMapperApp " + ChannelMap.versionText());
                writeJsonFile(sidecar, sc);
            end
        end

        function f = sidecarFile(probeFile)
            %sidecarFile  <folder>/<name>.chanmap.json next to <folder>/<name>.json.
            [folder, nm] = fileparts(string(probeFile));
            f = fullfile(folder, nm + ChannelMap.SidecarSuffix);
        end

        function r = resultStruct(T)
            %resultStruct  The per-site result as JSON lists.
            r = struct();
            r.site = num2cell(T.Site);
            r.hardwareChannel = num2cell(T.HardwareChannel);
            r.recordingRow0 = num2cell(T.RecordingRow0);
            r.flag = cellstr(T.Flag);
        end

        function m = mappingStruct(R, opts)
            %mappingStruct  The chain and its result as a saved-mapping JSON struct.
            %   M = ChannelMap.mappingStruct(R, Name=, Notes=) is what
            %   HardwareBank.saveEntry writes to hardware/mappings/<Name>.json
            %   and what the export's sidecar carries under "mapping".
            arguments
                R (1,1) struct
                opts.Name (1,1) string = ""
                opts.Notes (1,1) string = ""
            end
            c = R.Chain;
            m = struct();
            m.schema = 'ephys-hardware/1';
            m.kind = 'mapping';
            m.manufacturer = '';
            m.name = char(opts.Name);
            m.channels = height(R.Table);
            m.probe = '';
            if ~isempty(c.probe)
                m.probe = char(c.probe.Id);
            end
            m.package = char(c.package.Id);
            m.adaptors = {};
            hs = cell(1, numel(c.headstages));
            for i = 1:numel(c.headstages)
                hs{i} = struct('id', char(c.headstages(i).Entry.Id), 'channelOffset', c.headstages(i).ChannelOffset);
            end
            m.headstages = hs;
            ms = cell(1, numel(c.mates));
            for i = 1:numel(c.mates)
                ms{i} = struct('from', char(c.mates(i).From), 'to', char(c.mates(i).To), ...
                    'orientation', char(c.mates(i).Orientation));
            end
            m.mates = ms;
            rows = struct();
            rows.mode = char(c.rowsMode);
            if isempty(c.channelNumbers)
                rows.channelNumbers = [];
            else
                rows.channelNumbers = num2cell(c.channelNumbers(:));
            end
            rows.dataset = char(c.dataset);
            m.rows = rows;
            m.result = ChannelMap.resultStruct(R.Table);
            m.result = rmfield(m.result, 'flag');
            m.problems = cellstr(R.Problems);
            m.trust = char(R.Trust);
            m.notes = char(opts.Notes);
            m.source = 'ChannelMapperApp';
        end

        function t = versionText()
            %versionText  ephysVersion().Text, or "" when it cannot be read.
            t = "";
            try
                v = ephysVersion();
                t = string(v.Text);
            catch
            end
        end

        % ----------------------------------------------------------- geometry
        function S = sitesFromTemplate(name, opts)
            %sitesFromTemplate  Site geometry from a site-order template or generator.
            %   S = ChannelMap.sitesFromTemplate(NAME, ...) returns a table Site
            %   X Y Shank (um; y grows away from the tip). NAME is
            %     a NeuroNexus design ("A1x32-6mm-50-177") or template
            %       ("A1x32", "A4x8", "A1x32-Poly3", "Buzsaki32", ...; see
            %       ChannelMap.templates): the pitch and shank spacing default
            %       to the numbers in the design name
            %     "linear"        N sites from the tip up (Shanks of them)
            %     "multi_column"  Columns x PerColumn, column by column
            %                     (Stagger offsets every other column by half
            %                     a pitch)
            %     "tetrode"       Tetrodes per shank, four sites each
            %   Options: Pitch, ShankSpacing, ColumnSpacing (default the
            %   pitch), N, Shanks, Columns, PerColumn, Stagger, Tetrodes,
            %   Radius.
            arguments
                name (1,1) string
                opts.Pitch (1,1) double = NaN
                opts.ShankSpacing (1,1) double = NaN
                opts.ColumnSpacing (1,1) double = NaN
                opts.N (1,1) double = 16
                opts.Shanks (1,1) double = NaN
                opts.Columns (1,1) double = 2
                opts.PerColumn (1,1) double = 8
                opts.Stagger (1,1) logical = false
                opts.Tetrodes (1,1) double = 1
                opts.Radius (1,1) double = 12.5
            end
            key = lower(name);
            if any(key == ["linear" "multi_column" "tetrode"])
                pitch = pickNum(opts.Pitch, 50);
                spacing = pickNum(opts.ShankSpacing, 200);
                shanks = pickNum(opts.Shanks, 1);
                switch key
                    case "linear"
                        per = opts.N;
                        S = columnShankSites(shanks, per, repmat({1:per}, 1, 1), pitch, spacing);
                    case "multi_column"
                        cs = pickNum(opts.ColumnSpacing, pitch);
                        [site, X, Y, Sh] = deal([]);
                        per = opts.Columns * opts.PerColumn;
                        for s = 1:shanks
                            for c = 1:opts.Columns
                                j = (1:opts.PerColumn)';
                                site = [site; (s - 1) * per + (c - 1) * opts.PerColumn + j]; %#ok<AGROW>
                                X = [X; (s - 1) * spacing + (c - 1) * cs + 0 * j]; %#ok<AGROW>
                                Y = [Y; (j - 1) * pitch + opts.Stagger * mod(c - 1, 2) * pitch / 2]; %#ok<AGROW>
                                Sh = [Sh; s + 0 * j]; %#ok<AGROW>
                            end
                        end
                        S = table(site, X, Y, Sh, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
                    case "tetrode"
                        S = tetrodeSites(shanks, opts.Tetrodes, pickNum(opts.Pitch, 150), spacing, opts.Radius);
                end
                return
            end

            p = ChannelMap.parseDesignName(name);
            if p.Template == ""
                error('ChannelMap:UnknownTemplate', 'No site-order template for "%s".', name);
            end
            t = ChannelMap.templates();
            t = t(string({t.Name}) == p.Template);
            pitch = pickNum(opts.Pitch, pickNum(p.Pitch, 50));
            spacing = pickNum(opts.ShankSpacing, pickNum(p.ShankSpacing, 200));
            cs = pickNum(opts.ColumnSpacing, pitch);
            switch t.Kind
                case "column"
                    S = columnShankSites(t.Shanks, t.PerShank, t.Order, pitch, spacing);
                case "poly2"
                    % left column top -> bottom, right column top -> bottom, half a pitch up
                    L = t.Order{1}; Rt = t.Order{2}; nL = numel(L);
                    site = [L(:); Rt(:)];
                    X = [zeros(nL, 1); cs + zeros(numel(Rt), 1)];
                    Y = [((nL - 1):-1:0)' * pitch; ((numel(Rt) - 1):-1:0)' * pitch + pitch / 2];
                    S = table(site, X, Y, ones(size(site)), 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
                case "poly3"
                    % centre column top -> bottom from the tip up; side columns start one row below its top
                    Cc = t.Order{1}; L = t.Order{2}; Rt = t.Order{3}; nC = numel(Cc);
                    site = [L(:); Cc(:); Rt(:)];
                    X = [zeros(numel(L), 1); cs + zeros(nC, 1); 2 * cs + zeros(numel(Rt), 1)];
                    Y = [((numel(L)):-1:1)' * pitch; ((nC - 1):-1:0)' * pitch; ((numel(Rt)):-1:1)' * pitch];
                    S = table(site, X, Y, ones(size(site)), 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
                case "buzsaki"
                    % per shank: left column top -> bottom 1 2 3 4, right 8 7 6 5; staggered, 5 at the tip
                    fromTip = [5 4 6 3 7 2 8 1];
                    right = ismember(fromTip, 5:8);
                    [site, X, Y, Sh] = deal([]);
                    for s = 1:t.Shanks
                        site = [site; (s - 1) * 8 + fromTip(:)]; %#ok<AGROW>
                        X = [X; (s - 1) * spacing + cs * right(:)]; %#ok<AGROW>
                        Y = [Y; (0:7)' * pitch]; %#ok<AGROW>
                        Sh = [Sh; s + zeros(8, 1)]; %#ok<AGROW>
                    end
                    S = table(site, X, Y, Sh, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
                case "tetrode"
                    S = tetrodeSites(t.Shanks, t.PerShank / 4, pickNum(opts.Pitch, pickNum(p.Pitch, 150)), spacing, opts.Radius);
            end
            S = sortrows(S, 'Site');
        end

        function t = templates()
            %templates  The NeuroNexus site-order templates (from the package maps).
            %   Struct array: Name, Kind ("column" | "poly2" | "poly3" |
            %   "buzsaki" | "tetrode"), Shanks, PerShank, Order (per shank,
            %   from the tip up, for "column"; the column orders otherwise).
            il = @(n) reshape([1:n/2; n:-1:n/2+1], 1, []);     % 1 n 2 n-1 ... interleave
            t = struct('Name', {}, 'Kind', {}, 'Shanks', {}, 'PerShank', {}, 'Order', {});
            add("A1x16", "column", 1, 16, {il(16)});
            add("A1x32", "column", 1, 32, {il(32)});
            add("A1x32-Edge", "column", 1, 32, {1:32});
            add("A1x64-Edge", "column", 1, 64, {1:64});
            add("A4x16-Edge", "column", 4, 16, {1:16});
            add("A8x8-Edge", "column", 8, 8, {1:8});
            add("A2x16", "column", 2, 16, {il(16)});
            add("A4x8", "column", 4, 8, {il(8)});
            add("A4x16", "column", 4, 16, {il(16)});
            add("A8x4", "column", 8, 4, {il(4)});
            add("A8x8", "column", 8, 8, {il(8)});
            add("A16x1", "column", 16, 1, {1});
            add("A1x32-Poly2", "poly2", 1, 32, {[10 9 8 7 6 5 4 3 2 1 11 12 13 14 15 16], ...
                [23 24 25 26 27 28 29 30 31 32 22 21 20 19 18 17]});
            add("A1x32-Poly3", "poly3", 1, 32, {[17 16 18 15 19 14 20 13 21 12 22 11], ...
                [2 1 3 4 5 6 7 8 9 10], [31 32 30 29 28 27 26 25 24 23]});
            add("Buzsaki32", "buzsaki", 4, 8, {});
            add("Buzsaki64", "buzsaki", 8, 8, {});
            add("A4x2-tet", "tetrode", 4, 8, {});
            add("A8x1-tet", "tetrode", 8, 4, {});
            add("A4x4-tet", "tetrode", 4, 16, {});
            add("A2x2-tet", "tetrode", 2, 8, {});
            add("A4x1-tet", "tetrode", 4, 4, {});
            function add(name, kind, shanks, per, order)
                t(end + 1) = struct('Name', name, 'Kind', kind, 'Shanks', shanks, 'PerShank', per, 'Order', {order});
            end
        end

        function p = parseDesignName(name)
            %parseDesignName  Template, shanks, sites per shank, pitch and shank spacing of a design name.
            %   P = ChannelMap.parseDesignName("A4x8-5mm-50-200-177") returns
            %   Template "A4x8", Shanks 4, PerShank 8, Pitch 50,
            %   ShankSpacing 200. The numbers after "<length>mm-" are the
            %   pitch, the shank spacing when there is more than one shank,
            %   and the site area. Missing parts are "" / NaN.
            name = string(name);
            p = struct('Name', name, 'Template', "", 'Shanks', NaN, 'PerShank', NaN, ...
                'Pitch', NaN, 'ShankSpacing', NaN);
            % The template is the longest one the name starts with, followed
            % by nothing or by "-<length>mm": "A1x32-Poly3-10mm-..." is
            % A1x32-Poly3, and "A4x16-Poly2-5mm-..." has no template (A4x16
            % is the single-column design).
            t = ChannelMap.templates();
            for nm = string({t.Name})
                if startsWith(lower(name), lower(nm)) && strlength(nm) > strlength(p.Template)
                    rest = extractAfter(name, strlength(nm));
                    if rest == "" || ~isempty(regexp(rest, '^-\d+(\.\d+)?mm', 'once'))
                        p.Template = nm;
                    end
                end
            end
            tok = regexp(name, '^A(\d+)x(\d+)', 'tokens', 'once');
            if ~isempty(tok)
                p.Shanks = str2double(tok(1));
                p.PerShank = str2double(tok(2));
            end
            rest = regexp(name, '\d+mm-(.*)$', 'tokens', 'once');
            if ~isempty(rest)
                nums = str2double(string(regexp(rest(1), '\d+(\.\d+)?', 'match')));
                if ~isempty(nums)
                    p.Pitch = nums(1);
                end
                if p.Shanks > 1 && numel(nums) >= 3
                    p.ShankSpacing = nums(2);
                end
            end
        end
    end
end


function s = compactList(v)
%compactList  "1, 2, 5" for a short numeric list.
s = strjoin(compose("%g", v(:)'), ", ");
end


function [u, repeated] = uniqueWithRepeats(v)
%uniqueWithRepeats  The unique values of v, and those that occur more than once.
v = v(:);
u = unique(v);
repeated = zeros(0, 1);
if isempty(v)
    return
end
counts = histcounts(v, [u; Inf]);
repeated = u(counts(:) > 1);
end


function s = cellNameOf(cells, r, c)
%cellNameOf  "top:17" when the face's cells are known, else "(1,18)".
if isempty(cells)
    s = sprintf("(%d,%d)", r, c);
else
    s = ChannelMap.pinName(cells, r, c);
end
end


function s = hsLabelOf(chain, i)
%hsLabelOf  A headstage's name in the result, "#i" added when the chain has several.
s = chain.headstages(i).Entry.Name;
if numel(chain.headstages) > 1
    s = s + " #" + i;
end
end


function v = usedPkgOf(ms)
%usedPkgOf  The package face each resolved mate uses (NaN when it failed).
v = NaN(1, numel(ms));
for q = 1:numel(ms)
    v(q) = ms(q).PkgFace;
end
end


function s = csvQuote(s)
%csvQuote  Quote the CSV fields that hold a comma, a quote or a newline.
need = contains(s, [",", """", newline]);
s(need) = """" + replace(s(need), """", """""") + """";
end


function v = pickNum(v, default)
%pickNum  V, or DEFAULT when V is NaN.
if isnan(v)
    v = default;
end
end


function S = columnShankSites(nS, per, order, pitch, spacing)
%columnShankSites  One column per shank; ORDER{s} lists the shank's sites from the tip up.
[site, X, Y, Sh] = deal(zeros(0, 1));
for s = 1:nS
    o = order{min(s, numel(order))};
    o = o - min(o) + 1;
    site = [site; (s - 1) * per + o(:)]; %#ok<AGROW>
    X = [X; (s - 1) * spacing + zeros(numel(o), 1)]; %#ok<AGROW>
    Y = [Y; (0:numel(o) - 1)' * pitch]; %#ok<AGROW>
    Sh = [Sh; s + zeros(numel(o), 1)]; %#ok<AGROW>
end
S = sortrows(table(site, X, Y, Sh, 'VariableNames', {'Site', 'X', 'Y', 'Shank'}), 'Site');
end


function S = tetrodeSites(nS, nT, pitch, spacing, r)
%tetrodeSites  NT tetrodes per shank, four sites in a diamond of radius R, PITCH apart.
dx = [0 -r r 0];
dy = [r 0 0 -r];
[site, X, Y, Sh] = deal(zeros(0, 1));
k = 0;
for s = 1:nS
    for q = 1:nT
        site = [site; k + (1:4)']; %#ok<AGROW>
        X = [X; (s - 1) * spacing + dx(:)]; %#ok<AGROW>
        Y = [Y; r + (q - 1) * pitch + dy(:)]; %#ok<AGROW>
        Sh = [Sh; s + zeros(4, 1)]; %#ok<AGROW>
        k = k + 4;
    end
end
S = table(site, X, Y, Sh, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
end


function v = strs(S, name)
%strs  A string field of every element of a struct array, as a row (empty for none).
v = strings(1, numel(S));
for k = 1:numel(S)
    v(k) = S(k).(name);
end
end
