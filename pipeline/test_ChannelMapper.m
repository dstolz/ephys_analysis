function test_ChannelMapper()
%test_ChannelMapper  Verification suite for the channel mapper.
%   Covers ChannelMap (parsing vendor rows, mating connector faces,
%   resolving a probe -> package -> headstage -> recording-row chain, text
%   and Kilosort4 export), HardwareBank (the shipped pipeline/hardware
%   bank, saving entries, saved mappings) and ChannelMapperApp, headless.
%   The golden checks: NeuroNexus H32 + Intan RHD2132 reproduces
%   probeinterface's H32>RHD2132 pathway (G1), H64LP + RHD2164 reproduces
%   pipeline/probes/H64LP_4x16lin_probemap.json (G2), and H16 + the 16-channel
%   RHD2132 gives the rule-derived map (G3). No Python is needed.
%
%   Usage:  test_ChannelMapper

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('ChannelMapper_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
mkdir(root);
g = 'ChannelMapperApp';
savedPrefs = [];
if ispref(g)
    savedPrefs = getpref(g);
    rmpref(g);
end
cleanup = onCleanup(@() restorePrefsAndRoot(g, savedPrefs, root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end

hwFolder = HardwareBank.defaultFolder();
bank = HardwareBank(hwFolder);
G1 = [16 17 18 20 21 22 31 30 29 27 26 25 24 28 23 19 12 8 3 7 6 5 4 2 1 0 9 10 11 13 14 15];
G3 = [16 18 19 23 20 21 22 17 14 9 10 11 8 12 13 15];
ref64 = readJsonFile(fullfile(here, 'probes', 'H64LP_4x16lin_probemap.json'));

%% ---- 1. parseRow / faceFromRows ------------------------------------------------
fprintf('\n== 1. parseRow ==\n');
t = ChannelMap.parseRow("GUIDE REF1 18 27 28 29 17 30 31 32 1 2 3 16 4 5 6 15 GND GUIDE", 20);
check(numel(t) == 20 && t(1) == "GUIDE" && t(2) == "REF1" && t(3) == "18" && t(19) == "GND", ...
    "an H32 row parses to 20 canonical cells");
t = ChannelMap.parseRow("G R x in12 09 o R2 - NC", 9);
check(isequal(t, ["GND" "REF" "NC" "12" "9" "GUIDE" "REF2" "NC" "NC"]), ...
    "aliases: G, R, x, in12, 09, o, R2, -, NC");
check(errId(@() ChannelMap.parseRow("1 2 3", 4)) == "ChannelMap:BadRow", "a wrong cell count is ChannelMap:BadRow");
check(errId(@() ChannelMap.parseRow("1 Q7 3")) == "ChannelMap:BadRow", "an unknown token is ChannelMap:BadRow");
full = ChannelMap.faceFromRows(["REF1 18 27 28 29 17 30 31 32 1 2 3 16 4 5 6 15 GND"; ...
    "GND 20 21 22 23 19 24 25 26 7 8 9 14 10 11 12 13 REF2"], Id="main", Gender="male", ...
    Connector="omnetics-nano-36", Size=[2 20], Guides=[1 1; 1 20; 2 1; 2 20]);
check(isequal(full.Cells, bank.get("neuronexus/H32").Faces(1).Cells), ...
    "rows that leave out the guide posts get them back from the connector");

%% ---- 2. the shipped bank ---------------------------------------------------------
fprintf('\n== 2. HardwareBank ==\n');
E = bank.Entries;
bad = E(arrayfun(@(e) ~isempty(e.Problems), E));
check(isempty(bad), sprintf("every shipped entry is clean (%d entries)%s", numel(E), ...
    strjoin(arrayfun(@(e) newline + "      " + e.Id + ": " + strjoin(e.Problems, "; "), bad, 'UniformOutput', false), "")));
check(numel(unique([E.Id])) == numel(E), "ids are unique");
check(all(ismember(["connector" "headstage" "package" "probe" "mapping"], [E.Kind])), ...
    "the bank has connectors, headstages, packages, probes and a mapping");
conn = bank.list("connector");
okFaces = true; okHs = true; okPkg = true;
for e = [bank.list("headstage"); bank.list("package")]'
    for f = e.Faces'
        c = conn([conn.Name] == f.Connector);
        okFaces = okFaces && isscalar(c) && isequal(size(f.Cells), [c.Rows c.Cols]);
    end
    v = arrayfun(@(f) str2double(f.Cells(:)), e.Faces, 'UniformOutput', false);
    v = vertcat(v{:});
    v = v(isfinite(v));
    if e.Kind == "headstage"
        okHs = okHs && numel(unique(v)) == numel(v) && numel(v) == e.Channels;
    else
        okPkg = okPkg && isequal(sort(v)', 1:e.Channels);
    end
end
check(okFaces, "every face has its connector's rows x columns");
check(okHs, "headstage channels are distinct and number channels");
check(okPkg, "package cells are exactly sites 1..channels");
P = bank.list("probe");
check(all(arrayfun(@(p) numel(p.Sites) == p.Channels && numel(p.X) == p.Channels && ...
    numel(p.Y) == p.Channels && numel(p.Shank) == p.Channels, P)), "probe sites / x / y / shank all have channels entries");
M = bank.list("mapping");
okMap = true;
for e = M'
    try
        bank.chainFromMapping(e);
    catch
        okMap = false;
    end
end
check(okMap, "every shipped mapping's devices are in the bank");
check(isequal(bank.channelCounts("headstage", "intan"), [16 32 64]) && ...
    any(bank.manufacturers("probe") == "generic"), "channelCounts / manufacturers");
check(errId(@() bank.get("nobody/nothing")) == "HardwareBank:NotFound", "get of an unknown id is HardwareBank:NotFound");

% saveEntry round trip in a scratch bank: one face of one row, one-site probe
sb = fullfile(root, 'bank');
mkdir(fullfile(sb, 'connectors'));
tb = HardwareBank(sb);
tb.saveEntry(struct('schema', 'ephys-hardware/1', 'kind', 'connector', 'manufacturer', 'acme', ...
    'name', 'tiny-3', 'channels', 3, 'family', 'tiny-3', 'rows', 1, 'cols', 3, 'guides', [], ...
    'oneWay', true, 'pitchMm', 1, 'notes', '', 'source', ''));
hsRaw = struct('schema', 'ephys-hardware/1', 'kind', 'headstage', 'manufacturer', 'Acme', 'name', 'One', ...
    'channels', 3, 'channelLabel', 'ch%d', 'hardwareChannels', [0 2], 'view', 'face on', ...
    'faces', {{struct('id', 'main', 'connector', 'tiny-3', 'gender', 'female', 'rows', {{'0 1 2'}})}}, ...
    'notes', '', 'source', '');
file = tb.saveEntry(hsRaw);
txt = fileread(file);
e1 = tb.get("acme/One");
check(~isempty(regexp(txt, '"faces":\s*\[', 'once')) && ~isempty(regexp(txt, '"rows":\s*\[', 'once')) && ...
    ~isempty(regexp(txt, '"hardwareChannels":\s*\[', 'once')), "a one-face, one-row entry is written with lists");
check(isscalar(e1.Faces) && isequal(e1.Faces.Cells, ["0" "1" "2"]) && isempty(e1.Problems) && ...
    endsWith(file, fullfile("headstages", "acme", "One.json")), ...
    "it reloads as one face of one row, under headstages/acme/");
check(errId(@() tb.saveEntry(hsRaw)) == "HardwareBank:Exists", "saveEntry refuses to replace a file (Overwrite=false)");
tb.saveEntry(hsRaw, Overwrite=true);
check(tb.has("acme/One"), "Overwrite=true replaces it");
prRaw = struct('schema', 'ephys-hardware/1', 'kind', 'probe', 'manufacturer', 'acme', 'name', 'dot', ...
    'channels', 1, 'shanks', 1, 'sites', 1, 'x', 0, 'y', 0, 'shank', 1, 'notes', '', 'source', '');
file = tb.saveEntry(prRaw);
check(~isempty(regexp(fileread(file), '"sites":\s*\[', 'once')) && tb.get("acme/dot").Sites == 1, ...
    "a one-site probe keeps its lists");
badPkg = struct('schema', 'ephys-hardware/1', 'kind', 'package', 'manufacturer', 'acme', 'name', 'Holes', ...
    'channels', 3, 'faces', {{struct('id', 'main', 'connector', 'tiny-3', 'gender', 'male', 'rows', {{'1 2 NC'}})}});
check(errId(@() tb.saveEntry(badPkg)) == "HardwareBank:Invalid", "an entry with problems is refused (HardwareBank:Invalid)");

%% ---- 3. mating ------------------------------------------------------------------
fprintf('\n== 3. mate ==\n');
h32 = bank.get("neuronexus/H32").Faces(1);
r32 = bank.get("intan/RHD2132-32ch").Faces(1);
h64 = bank.get("neuronexus/H64LP").Faces;
r64 = bank.get("intan/RHD2164-64ch").Faces;
h16 = bank.get("neuronexus/H16").Faces(1);
r16 = bank.get("intan/RHD2132-16ch").Faces(1);
pairsOk = true; safeOk = true; invOk = true;
for o = ChannelMap.Orientations
    for pr = {{h32, r32}, {h64(1), r64(1)}, {h64(2), r64(2)}, {h64(1), r64(2)}}
        a = pr{1}{1}; b = pr{1}{2};
        M = ChannelMap.mate(a, b, o);
        pairsOk = pairsOk && height(unique(M(:, {'DownRow', 'DownCol'}))) == numel(a.Cells);
        gnd = M.UpValue == "GND" | M.DownValue == "GND";
        ref = startsWith(M.UpValue, "REF") | startsWith(M.DownValue, "REF");
        safeOk = safeOk && all(M.UpValue(gnd) == M.DownValue(gnd)) && ...
            all(startsWith(M.UpValue(ref), "REF") & startsWith(M.DownValue(ref), "REF"));
        M2 = ChannelMap.mate(b, a, o);
        for k = 1:height(M)
            j = find(M2.UpRow == M.DownRow(k) & M2.UpCol == M.DownCol(k));
            invOk = invOk && isscalar(j) && M2.DownRow(j) == M.UpRow(k) && M2.DownCol(j) == M.UpCol(k);
        end
    end
end
check(pairsOk, "reference and rotated are bijections");
check(safeOk, "36-pin faces keep GND on GND and REF on REF in both orientations");
check(invOk, "mating back returns every cell to where it started");
p0 = ChannelMap.mateProblems(ChannelMap.mate(h32, r32, "reference"));
p1 = ChannelMap.mateProblems(ChannelMap.mate(h32, r32, "rotated"), Orientation="rotated");
p2 = ChannelMap.mateProblems(ChannelMap.mate(h16, r16, "rotated"), Orientation="rotated", OneWay=r16.OneWay);
check(isempty(p0) && isempty(p1), "H32 / RHD2132 has no problems either way");
check(r16.OneWay && ~isempty(p2) && any(contains(p2, "one way")) && any(contains(p2, "GUIDE")), ...
    "H16 / RHD2132-16ch rotated is reported (one way only, a guide post meets a pin)");
check(isequal(ChannelMap.defaultMates(h64, r64, "reference"), [1 1; 2 2]) && ...
    isequal(ChannelMap.defaultMates(h64, r64, "rotated"), [1 2; 2 1]), ...
    "defaultMates pairs top-top in reference and top-bottom rotated");
check(isequal(ChannelMap.defaultMates(h64, [r32; r32], "rotated", [1 2]), [1 1; 2 2]), ...
    "rotated keeps separate headstages in order");
check(errId(@() ChannelMap.mate(h32, r16)) == "ChannelMap:FamilyMismatch" && ...
    errId(@() ChannelMap.mate(h32, h32)) == "ChannelMap:GenderMismatch", "family and gender mismatches are errors");

%% ---- 4. G1: H32 -> RHD2132 ----------------------------------------------------------
fprintf('\n== 4. G1 ==\n');
R1 = ChannelMap.resolve(makeChain(bank, "generic/linear32", "neuronexus/H32", "intan/RHD2132-32ch"));
check(isequal(R1.Table.HardwareChannel', G1), "H32 + RHD2132 (reference) = probeinterface's H32>RHD2132");
check(isequal(R1.Table.RecordingRow0', G1) && isempty(R1.Problems) && R1.Trust == "verified", ...
    "in-order rows equal the hardware channels, no problems, trust verified");
R1n = ChannelMap.resolve(makeChain(bank, "", "neuronexus/H32", "intan/RHD2132-32ch"));
check(isequal(R1n.Table.HardwareChannel', G1) && all(isnan(R1n.Table.X)), "the same without a probe design (no geometry)");
Rm = ChannelMap.resolve(bank.chainFromMapping(bank.get("H32_A1x32_RHD2132")));
check(isequal(Rm.Table.HardwareChannel', G1), "the shipped mapping H32_A1x32_RHD2132 gives G1");
check(contains(ChannelMap.pathText(R1, 18), "in8") && contains(ChannelMap.pathText(R1, 18), "row 9 (1-based) / 8 (0-based)") && ...
    contains(ChannelMap.pathText(R1, 18), "top:2") && contains(ChannelMap.pathText(R1, 18), "top:17"), ...
    "pathText: site 18 -> H32 top:2 -> RHD2132 top:17 -> in8 -> row 9 / 8");

%% ---- 5. G2: H64LP -> RHD2164, exported ------------------------------------------------
fprintf('\n== 5. G2 ==\n');
c2 = makeChain(bank, "neuronexus/A4x16-Poly2-5mm-20s-lin-160", "neuronexus/H64LP", "intan/RHD2164-64ch");
R2 = ChannelMap.resolve(c2);
f2 = fullfile(root, 'H64LP_export.json');
[pf, sc] = ChannelMap.exportKS4(R2, f2);
w = readJsonFile(pf);
check(isequal(w.chanMap(:), ref64.chanMap(:)), "H64LP + RHD2164 chanMap = H64LP_4x16lin_probemap.json, site by site");
check(isequal(w.xc(:), ref64.xc(:)) && isequal(w.yc(:), ref64.yc(:)) && isequal(w.kcoords(:), ref64.kcoords(:)) && w.n_chan == 64, ...
    "xc / yc / kcoords / n_chan equal the lab file");
check(R2.Trust == "verified" && isempty(R2.Problems), "trust verified, no problems");
c2r = makeChain(bank, "neuronexus/A4x16-Poly2-5mm-20s-lin-160", "neuronexus/H64LP", "intan/RHD2164-64ch", Orientation="rotated");
R2r = ChannelMap.resolve(c2r);
check(~isequal(R2r.Table.RecordingRow0, R2.Table.RecordingRow0) && isequal(sort(R2r.Table.RecordingRow0), (0:63)') && ...
    isempty(R2r.Problems) && R2r.Trust == "unverified", "rotated: other rows, the same set, no problems, unverified");
check(isequal([c2r.mates.To], ["headstage[1]:bottom" "headstage[1]:top"]), "rotated pairs top with bottom");

%% ---- 6. G3: H16 -> RHD2132 16-channel ---------------------------------------------
fprintf('\n== 6. G3 ==\n');
c3 = makeChain(bank, "generic/linear16", "neuronexus/H16", "intan/RHD2132-16ch");
R3 = ChannelMap.resolve(c3);
check(isequal(R3.Table.HardwareChannel', G3) && isequal(R3.Table.RecordingRow0', G3 - 8) && R3.Trust == "rule-derived", ...
    "H16 + RHD2132-16ch: channels 8..23, rows 0..15 in order, rule-derived");
c3.channelNumbers = 8:23;
check(isequal(ChannelMap.resolve(c3).Table.RecordingRow0', G3 - 8), "a dataset recording 8..23 gives the same rows");
c3.channelNumbers = setdiff(8:23, 10);
T3 = ChannelMap.resolve(c3).Table;
s10 = find(G3 == 10);
want = G3 - 8 - (G3 > 10);
want(s10) = NaN;
check(isnan(T3.RecordingRow0(s10)) && T3.Flag(s10) == "not recorded" && isequaln(T3.RecordingRow0', want), ...
    "channel 10 missing: its site is not recorded, later rows shift by one");

%% ---- 7. two headstages ----------------------------------------------------------------
fprintf('\n== 7. Two headstages ==\n');
c7 = makeChain(bank, "neuronexus/A4x16-Poly2-5mm-20s-lin-160", "neuronexus/H64LP", ["intan/RHD2132-32ch" "intan/RHD2132-32ch"], Offsets=[0 32]);
R7 = ChannelMap.resolve(c7);
check(isequal([c7.mates.To], ["headstage[1]:main" "headstage[2]:main"]), "H64LP top and bottom go to the two headstages");
check(isequal(sort(R7.Table.RecordingRow0), (0:63)') && isempty(R7.Problems) && R7.Trust == "rule-derived" && R7.NChan == 64, ...
    "offsets 0 and 32: 64 distinct rows 0..63, no problems, rule-derived");
c7.headstages(2).ChannelOffset = 0;
R7b = ChannelMap.resolve(c7);
check(any(contains(R7b.Problems, "share hardware channels")) && any(contains(R7b.Problems, "all land on")), ...
    "without an offset the shared channels are reported");

%% ---- 8. export ---------------------------------------------------------------------
fprintf('\n== 8. exportKS4 ==\n');
check(isempty(probeMapProblems(pf)), "the exported probe passes probeMapProblems");
s = readJsonFile(sc);
check(isfile(sc) && endsWith(sc, "H64LP_export.chanmap.json") && s.schema == "ephys-channel-map/1" && ...
    DatasetTracker.classifyJson(s) ~= "probe" && ~isfield(s, 'chanMap'), "the sidecar is written and is not taken for a probe");
check(contains(w.notes, "neuronexus/H64LP") && contains(w.notes, "verified"), "notes carry the chain and its trust");
one = makeChain(bank, "generic/linear32", "neuronexus/H32", "intan/RHD2132-32ch");
one.probe.Sites = 18; one.probe.X = 0; one.probe.Y = 0; one.probe.Shank = 1;
pf1 = ChannelMap.exportKS4(ChannelMap.resolve(one), fullfile(root, 'one.json'), Sidecar=false);
check(~isempty(regexp(fileread(pf1), '"chanMap":\s*\[', 'once')) && ~isfile(ChannelMap.sidecarFile(pf1)), ...
    "a one-site chain writes chanMap as a list (and no sidecar when asked)");
cg = makeChain(bank, "generic/linear32", "neuronexus/H32", "intan/RHD2132-32ch");
cg.package.Faces(1) = ChannelMap.faceFromRows(["GUIDE REF1 GND 27 28 29 17 30 31 32 1 2 3 16 4 5 6 15 18 GUIDE"; ...
    "GUIDE GND 20 21 22 23 19 24 25 26 7 8 9 14 10 11 12 13 REF2 GUIDE"], Id="main", Gender="male", Connector="omnetics-nano-36");
Rg = ChannelMap.resolve(cg);
check(Rg.Table.Flag(18) == "GND" && isnan(Rg.Table.RecordingRow0(18)) && any(contains(Rg.Problems, "Site 18 lands on GND")), ...
    "a site wired to GND is flagged and reported");
check(errId(@() ChannelMap.exportKS4(Rg, fullfile(root, 'gnd.json'), DropUnmapped=false)) == "ChannelMap:Unmapped", ...
    "DropUnmapped=false refuses it (ChannelMap:Unmapped)");
pfg = ChannelMap.exportKS4(Rg, fullfile(root, 'gnd.json'));
wg = readJsonFile(pfg);
check(numel(wg.chanMap) == 31 && contains(wg.notes, "left out: sites 18 (GND)"), "DropUnmapped leaves it out and says so");
check(errId(@() ChannelMap.exportKS4(R1n, fullfile(root, 'nogeo.json'))) == "ChannelMap:NoGeometry", ...
    "exporting without a probe design is ChannelMap:NoGeometry");

%% ---- 9. toText -------------------------------------------------------------------------
fprintf('\n== 9. toText ==\n');
tsv = ChannelMap.toText(Rg.Table);
L = splitlines(strip(tsv, 'right', newline));
check(numel(L) == height(Rg.Table) + 1 && startsWith(L(1), "Site" + char(9)), "TSV: a header and one line per site");
f18 = split(L(19), char(9));
check(f18(1) == "18" && f18(Rg.Table.Properties.VariableNames == "RecordingRow0") == "", "NaN is written as an empty cell");
check(numel(splitlines(strip(ChannelMap.toText(Rg.Table, Format="markdown"), 'right', newline))) == height(Rg.Table) + 2 && ...
    numel(splitlines(strip(ChannelMap.toText(Rg.Table, Format="csv"), 'right', newline))) == height(Rg.Table) + 1, ...
    "Markdown and CSV line counts");
Lc = splitlines(ChannelMap.toText(R1.Table, SortBy="channel"));
check(startsWith(Lc(2), "26" + char(9)), "SortBy channel starts with the site on row 0 (site 26)");
chanMap = []; site = []; %#ok<NASGU>
eval(ChannelMap.toText(Rg.Table, Format="matlab"));
check(isequaln(chanMap, Rg.Table.RecordingRow0') && isequal(site, 1:32), "the MATLAB text evaluates to the 0-based chanMap");

%% ---- 10. saved mappings ---------------------------------------------------------------
fprintf('\n== 10. Saved mappings ==\n');
mb = fullfile(root, 'bank2');
copyfile(hwFolder, mb);
bank2 = HardwareBank(mb);
c10 = c7;
c10.headstages(2).ChannelOffset = 32;
c10.channelNumbers = 0:63;
c10.rowsMode = "custom";
R10 = ChannelMap.resolve(c10);
bank2.saveEntry(ChannelMap.mappingStruct(R10, Name="two heads", Notes="round trip"));
e10 = bank2.get("two_heads");
R10b = ChannelMap.resolve(bank2.chainFromMapping(e10));
check(isequaln(R10b.Table, R10.Table) && R10b.Summary == R10.Summary, "a saved mapping reloads to the same result");
check(isequal(e10.Mapping.Result.RecordingRow0, R10.Table.RecordingRow0) && e10.Mapping.RowsMode == "custom" && ...
    isequal(e10.Mapping.ChannelNumbers', 0:63) && e10.Notes == "round trip", "its result, rows mode, channel list and notes are kept");
check(errId(@() bank2.saveEntry(ChannelMap.mappingStruct(R10, Name="two heads"))) == "HardwareBank:Exists", ...
    "saving it again needs Overwrite");

%% ---- 11. ChannelMapperApp, headless -------------------------------------------------
fprintf('\n== 11. ChannelMapperApp ==\n');
gb = fullfile(root, 'bank3');
copyfile(hwFolder, gb);
m = ChannelMapperApp(BankFolder=gb);
check(isvalid(m.Fig) && m.MappingName == "H32_A1x32_RHD2132" && isempty(m.App), ...
    "standalone, with no remembered chain it opens the bank's first mapping");
m.selectProbe("generic/linear32");
m.selectPackage("neuronexus/H32");
m.selectHeadstage("intan/RHD2132-32ch");
check(isequal(m.Result.Table.HardwareChannel', G1) && m.HeadstageCount == 1, "selectProbe / selectPackage / selectHeadstage give G1");
m.onFaceClick("package:main", struct('IntersectionPoint', [3 1 0]));
s1 = selState(m);
check(m.Selection.site == 18 && isequal(m.ResultTable.Selection, find(m.ResultOrder == find(m.Result.Table.Site == 18))) && ...
    contains(string(m.PathLabel.Text), "in8") && isequal(amberCount(m), [1 1]), ...
    "clicking H32 pin top:2 selects site 18: table row, amber pins on both faces, the path through in8");
check(isequal([m.SelMarker.XData m.SelMarker.YData], [m.Result.Table.X(18) m.Result.Table.Y(18)]), "the ring sits on site 18");
m.select("none");
row = find(m.ResultOrder == find(m.Result.Table.Site == 18));
m.onResultRowSelected(struct('Indices', [row 1; row 2; row 3]));
check(isequal(selState(m), s1), "selecting its table row gives the same selection");
m.select("none");
m.onProbeClick(struct('IntersectionPoint', [m.Result.Table.X(18) + 3, m.Result.Table.Y(18) - 4, 0]));
check(isequal(selState(m), s1), "clicking next to it on the probe gives the same selection");
m.select("none");
m.onFaceClick("headstage[1]:main", struct('IntersectionPoint', [3, 2 + 1.7 + 1, 0]));
check(isequal(selState(m), s1), "clicking in8 on the (mirrored) headstage face selects site 18 too");
m.onFaceClick("package:main", struct('IntersectionPoint', [19 1 0]));
check(isnan(m.Selection.site) && contains(string(m.PathLabel.Text), "GND") && contains(string(m.PathLabel.Text), "meets") && ...
    isequal(amberCount(m), [1 1]) && isempty(m.ResultTable.Selection), "a GND pin selects the pin and the pin it meets, no site");
m.setOrientation(1, "rotated");
check(~isequal(m.Result.Table.RecordingRow0', G1) && contains(string(m.ProblemsLabel.Text), "No problems") && ...
    isequal(m.ProblemsLabel.FontColor, [0 0.5 0]) && m.Result.Trust == "unverified", ...
    "rotated: other rows, still no problems (green), unverified");
m.setOrientation(1, "reference");
L = splitlines(strip(m.copyText("tsv"), 'right', newline));
check(numel(L) == 33 && contains(m.copyText("matlab"), "chanMap = ["), "copyText: TSV of 32 sites, MATLAB vectors");
m.selectProbe("neuronexus/A1x32-6mm-50-177");
pfG = fullfile(root, 'gui_probe.json');
[pfG, scG] = m.exportKS4(pfG);
check(isfile(pfG) && isfile(scG) && isempty(probeMapProblems(pfG)) && isequal(readJsonFile(pfG).chanMap', G1), ...
    "exportKS4 writes the probe and its sidecar without dialogs");
fileM = m.saveMapping("gui test");
check(isfile(fileM) && m.MappingName == "gui_test" && m.Bank.has("gui_test"), "saveMapping writes mappings/gui_test.json");
m.selectPackage("neuronexus/H16");
check(m.HeadstageId == "intan/RHD2132-16ch" && isequal(m.Result.Table.HardwareChannel', G3), ...
    "choosing H16 brings the 16-channel RHD2132 (G3)");
m.loadMapping("gui_test");
check(m.PackageId == "neuronexus/H32" && m.ProbeId == "neuronexus/A1x32-6mm-50-177" && ...
    isequal(m.Result.Table.HardwareChannel', G1), "loadMapping brings the chain back");
m.loadMapping(scG);
check(m.PackageId == "neuronexus/H32" && isequal(m.Result.Table.RecordingRow0', G1), "loadMapping reads an export's sidecar");
m.setRows("custom", [0:15 17:31 16]);
check(m.Result.Table.RecordingRow0(m.Result.Table.HardwareChannel == 16) == 31 && ...
    m.Result.Table.RecordingRow0(m.Result.Table.HardwareChannel == 17) == 16, "setRows custom: rows follow the list");
m.setRows("in-order");
check(isequal(ChannelMapperApp.parseChannelList("0-3, 7 9:10"), [0 1 2 3 7 9 10]) && ...
    errId(@() ChannelMapperApp.parseChannelList("1-")) == "ChannelMapperApp:BadList", "parseChannelList");
m.selectPackage("neuronexus/H64LP");
m.selectHeadstage("intan/RHD2132-32ch", 2);
check(isequal(m.Offsets, [0 32]) && isequal(sort(m.Result.Table.RecordingRow0), (0:63)') && isempty(m.Result.Problems), ...
    "two RHD2132 on H64LP: offsets 0 and 32, rows 0..63");
m.onMateEdited(struct('Indices', [2 5], 'NewData', 0, 'PreviousData', 32));
check(any(contains(m.Result.Problems, "share hardware channels")), "editing the second offset to 0 is reported");
m.onMateEdited(struct('Indices', [2 5], 'NewData', 32, 'PreviousData', 0));
check(isempty(m.Result.Problems), "and setting it back clears it");

% the entry editor, through its public save path
ed = m.onNewEntry("headstage");
ed.Name.Value = 'HS-test';
ed.Manufacturer.Value = 'acme';
ed.Channels.Value = 16;
ed.Connector.Value = 'omnetics-nano-18';
ed.HardwareRange.Value = '8-23';
ed.RowsArea.Value = {'19 18 17 16 15 14 13 12'; 'REF 20 21 22 23 8 9 10 11 GND'};
m.editorRefresh();
check(contains(string(m.Editor.Check.Text), "Ready") && isequal(size(m.Editor.Faces(1).Cells), [2 10]), ...
    "the headstage editor parses pasted rows (guide posts put back) and is ready");
fileE = m.onEditorSave();
e = m.Bank.get("acme/HS-test");
check(isfile(fileE) && isequal(e.Faces(1).Cells, m.Bank.get("intan/RHD2132-16ch").Faces(1).Cells) && ...
    isequal(e.HardwareChannels', [8 23]) && m.HeadstageId == "acme/HS-test" && isempty(m.Editor), ...
    "Save to bank writes it, round trips, closes the editor and selects it");
ed = m.onNewEntry("probe");
ed.Name.Value = 'dot4';
ed.Manufacturer.Value = 'acme';
ed.GenDrop.Value = 'Linear';
ed.GenN.Value = 4;
ed.GenPitch.Value = 25;
m.editorGenerate();
check(height(m.Editor.Sites.Data) == 4 && m.Editor.Channels.Value == 4, "the probe editor generates sites");
m.editorImport("ks4", fullfile(here, 'probes', 'H64LP_4x16lin_probemap.json'));
check(height(m.Editor.Sites.Data) == 64 && isequal(unique(m.Editor.Sites.Data.Shank)', 1:4) && ...
    contains(string(m.Editor.Notes.Value), "order"), "it imports a Kilosort4 probe (sites by order, shanks 1..4)");
m.editorGenerate();
m.onEditorSave();
check(m.Bank.has("acme/dot4") && m.ProbeId == "acme/dot4", "a generated probe design saves and is selected");
m.loadMapping("gui_test");
close(m.Fig);
check(~isvalid(m) && ispref(g, 'LastChain') && ispref(g, 'BankFolder'), "closing the window deletes it and saves the preferences");
m2 = ChannelMapperApp();
check(m2.Bank.Folder == string(gb) && m2.PackageId == "neuronexus/H32" && m2.ProbeId == "neuronexus/A1x32-6mm-50-177", ...
    "reopened, it comes back on the same bank and chain");
delete(m2);

%% ---- geometry templates --------------------------------------------------------------
fprintf('\n== Templates ==\n');
S = ChannelMap.sitesFromTemplate("A4x8-5mm-50-200-177");
check(isequal(S{[1 8 2 9], {'X', 'Y'}}, [0 0; 0 50; 0 100; 200 0]) && isequal(S.Shank', repelem(1:4, 8)), ...
    "A4x8-5mm-50-200-177 matches probeinterface (1, 8, 2 up the shank; 200 um shanks)");
S = ChannelMap.sitesFromTemplate("A1x32-Poly3-10mm-50-177");
check(isequal(S{[17 2 31 11 10 23], {'X', 'Y'}}, [50 550; 0 500; 100 500; 50 0; 0 50; 100 50]), ...
    "A1x32-Poly3-10mm-50-177 matches probeinterface");
p = ChannelMap.parseDesignName("A2x16-10mm-100-500-177");
check(p.Template == "A2x16" && p.Pitch == 100 && p.ShankSpacing == 500 && ...
    ChannelMap.parseDesignName("A4x16-Poly2-5mm-20s-lin-160").Template == "", ...
    "design names: pitch and shank spacing; no template for a Poly2 variant");
S = ChannelMap.sitesFromTemplate("linear", N=4, Pitch=20, Shanks=2);
check(isequal(S.Site', 1:8) && isequal(S.Y', [0 20 40 60 0 20 40 60]) && isequal(S.X', [0 0 0 0 200 200 200 200]), ...
    "the linear generator");

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_ChannelMapper:Failed', '%d checks failed.', nFail);
end
end


function chain = makeChain(bank, probeId, packageId, headstageIds, opts)
%makeChain  A chain of bank entries with default mates.
arguments
    bank
    probeId (1,1) string
    packageId (1,1) string
    headstageIds (1,:) string
    opts.Orientation (1,1) string = "reference"
    opts.Offsets double = zeros(1, numel(headstageIds))
end
chain = struct();
chain.probe = [];
if probeId ~= ""
    chain.probe = bank.get(probeId);
end
chain.package = bank.get(packageId);
chain.adaptors = {};
hs = struct('Entry', {}, 'ChannelOffset', {});
down = ChannelMap.emptyFaces();
dev = [];
names = strings(0, 1);
for i = 1:numel(headstageIds)
    e = bank.get(headstageIds(i));
    hs(i) = struct('Entry', e, 'ChannelOffset', opts.Offsets(i));
    down = [down; e.Faces(:)]; %#ok<AGROW>
    dev = [dev, i + zeros(1, numel(e.Faces))]; %#ok<AGROW>
    names = [names; "headstage[" + i + "]:" + [e.Faces.Id]']; %#ok<AGROW>
end
chain.headstages = hs;
pairs = ChannelMap.defaultMates(chain.package.Faces, down, opts.Orientation, dev);
mates = struct('From', {}, 'To', {}, 'Orientation', {});
for k = 1:size(pairs, 1)
    mates(k) = struct('From', "package:" + chain.package.Faces(pairs(k, 1)).Id, ...
        'To', names(pairs(k, 2)), 'Orientation', opts.Orientation);
end
chain.mates = mates;
chain.channelNumbers = [];
chain.rowsMode = "in-order";
chain.dataset = "";
end


function s = selState(m)
%selState  What a selection shows: the site, the table row, the path, the ring.
s = {m.Selection.site, m.ResultTable.Selection, string(m.PathLabel.Text), [m.SelMarker.XData m.SelMarker.YData]};
end


function n = amberCount(m)
%amberCount  Amber cells on each drawn face that has any.
amber = ChannelMapperApp.Colors.selected;
n = zeros(1, 0);
for k = 1:numel(m.FaceDraw)
    c = nnz(all(abs(m.FaceDraw(k).Patch.FaceVertexCData - amber) < 1e-9, 2));
    if c > 0
        n(end + 1) = c; %#ok<AGROW>
    end
end
end


function id = errId(fn)
%errId  The identifier of the error FN raises ("" when it does not).
id = "";
try
    fn();
catch ME
    id = string(ME.identifier);
end
end


function restorePrefsAndRoot(g, savedPrefs, root)
try
    if ispref(g)
        rmpref(g);
    end
    if isstruct(savedPrefs)
        for f = string(fieldnames(savedPrefs))'
            setpref(g, char(f), savedPrefs.(f));
        end
    end
catch
end
try
    if isfolder(root)
        rmdir(root, 's');
    end
catch
end
end
