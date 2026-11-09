classdef test_DatasetVariables < matlab.unittest.TestCase
    %test_DatasetVariables  Dataset variables: the rules (DatasetVariables), the writer (writeManifestVariables), the dataset (EphysDataset).
    %   A dataset in an empty temporary folder (no recording needed): names
    %   suggested from labels, values read from typed text, a set and its
    %   history through create / update / rename / remove, the columns and
    %   the vocabulary, the manifest written three ways (file, folder,
    %   dataset) with only "variables", "variable_history" and "updated"
    %   changing, the units' µ kept, no value in the history (only the
    %   latest is kept), a request that changes nothing writing nothing, and two writers' changes merged by EphysDataset.writeManifest.
    %
    %   Usage:  runtests("test_DatasetVariables")

    properties
        Dir
        Ds
    end

    methods (TestMethodSetup)
        function makeDataset(tc)
            tc.Dir = string(tempname);
            mkdir(tc.Dir);
            tc.addTeardown(@() rmdir(tc.Dir, 's'));
            tc.Ds = EphysDataset(tc.Dir, AutoMetadata=false, Name="subjA_260101_120000");
        end
    end

    methods (Test)
        function suggestsNamesFromLabels(tc)
            tc.verifyEqual(DatasetVariables.suggestName("Probe Depth"), "probeDepth");
            tc.verifyEqual(DatasetVariables.suggestName("Probe depth (µm)"), "probeDepthUm", 'µ reads as u.');
            tc.verifyEqual(DatasetVariables.suggestName("LFP power"), "lfpPower", 'A first word in capitals is lowercased whole.');
            tc.verifyEqual(DatasetVariables.suggestName("CA1 depth"), "ca1Depth");
            tc.verifyEqual(DatasetVariables.suggestName("3rd day"), "x3rdDay", 'A name never starts with a digit.');
            tc.verifyEqual(DatasetVariables.suggestName("  -- "), "", 'No letter or digit: no name.');
            tc.verifyEqual(DatasetVariables.suggestName("Probe Depth", ["probedepth" "probeDepth2"]), "probeDepth3", ...
                'A taken name (any case) gets a number.');
            long = DatasetVariables.suggestName(join(repmat("word", 1, 30), " "));
            tc.verifyLessThanOrEqual(strlength(long), DatasetVariables.MaxNameLength);
            tc.verifyTrue(isvarname(DatasetVariables.ColumnPrefix + long), 'var_<name> is a valid table column.');
            tc.verifyEqual(DatasetVariables.suggestLabel("probeDepthUm"), "Probe Depth Um");
            tc.verifyEqual(DatasetVariables.suggestLabel("drug_dose"), "Drug Dose");
        end

        function checksNamesLabelsAndValues(tc)
            tc.verifyTrue(DatasetVariables.checkName("probeDepth"));
            [ok, why] = DatasetVariables.checkName("probe depth");
            tc.verifyFalse(ok); tc.verifySubstring(why, "not a valid name");
            [ok, why] = DatasetVariables.checkName("end");
            tc.verifyFalse(ok); tc.verifySubstring(why, "keyword");
            [ok, why] = DatasetVariables.checkName("ProbeDepth", "probeDepth");
            tc.verifyFalse(ok); tc.verifySubstring(why, "named");
            tc.verifyFalse(DatasetVariables.checkLabel("   "));
            tc.verifyFalse(DatasetVariables.checkLabel("two" + newline + "lines"));
            [v, ok] = DatasetVariables.parseValue(" 1200 ");
            tc.verifyTrue(ok); tc.verifyEqual(v, 1200);
            [v, ok] = DatasetVariables.parseValue("1e-3", "auto");
            tc.verifyTrue(ok); tc.verifyEqual(v, 1e-3);
            v = DatasetVariables.parseValue("007", "text");
            tc.verifyEqual(v, "007", 'Text keeps a number-like value as typed.');
            v = DatasetVariables.parseValue("ofc", "auto");
            tc.verifyEqual(v, "ofc");
            [v, ok, why] = DatasetVariables.parseValue("abc", "number");
            tc.verifyFalse(ok); tc.verifyEmpty(v); tc.verifySubstring(why, "not a number");
            [v, ok] = DatasetVariables.parseValue("", "number");
            tc.verifyTrue(ok); tc.verifyEmpty(v, 'Empty text: no value, no error.');
            [~, ok] = DatasetVariables.parseValue(Inf);
            tc.verifyFalse(ok, 'A number must be finite.');
            tc.verifyError(@() DatasetVariables.entry("", 1), 'DatasetVariables:BadLabel');
            tc.verifyError(@() DatasetVariables.entry("X", NaN), 'DatasetVariables:BadValue');
            tc.verifyError(@() DatasetVariables.entry("X", 1, Units=repmat('u', 1, 30)), 'DatasetVariables:BadUnits');
            tc.verifyError(@() DatasetVariables.require(struct('a', DatasetVariables.entry("A", 1), 'A', DatasetVariables.entry("A", 2))), ...
                'DatasetVariables:Duplicate');
        end

        function logsEveryChange(tc)
            e = @(lab, v, varargin) DatasetVariables.entry(lab, v, varargin{:});
            s1 = struct('probeDepth', e("Probe Depth", 1200, Units="µm"));
            [s, h, a] = DatasetVariables.update(struct(), [], s1, Time="2026-01-01 10:00:00", User="me");
            tc.verifyEqual([a.action], "created");
            tc.verifyEqual(s.probeDepth.created, "2026-01-01 10:00:00");
            tc.verifyEqual(h(1).user, "me");
            s2 = s; s2.probeDepth.value = 1250; s2.cohort = e("Cohort", "A");
            [s, h, a] = DatasetVariables.update(s, h, s2, Time="2026-01-02 10:00:00");
            tc.verifyEqual([a.action], ["updated" "created"]);
            tc.verifyEqual(a(1).changed, "value");
            tc.verifyEqual(s.probeDepth.created, "2026-01-01 10:00:00", 'An update keeps when it was made.');
            tc.verifyEqual(s.probeDepth.updated, "2026-01-02 10:00:00");
            tc.verifyFalse(any(isfield(h, {'value', 'label', 'units', 'description'})), ...
                'The history says what changed and when, never what it held.');
            [s, h, a] = DatasetVariables.update(s, h, s, Time="2026-01-03 10:00:00");
            tc.verifyEmpty(a, 'The same set: no row.');
            s3 = struct('depth', s.probeDepth);
            [s, h, a] = DatasetVariables.update(s, h, s3, Renamed=["probeDepth" "depth"], Time="2026-01-04 10:00:00");
            tc.verifyEqual([a.action], ["renamed" "removed"]);
            tc.verifyEqual(a(1).previous_name, "probeDepth");
            tc.verifyEqual(a(1).changed, "name");
            tc.verifyEqual(a(2).name, "cohort");
            tc.verifyEqual(s.depth.created, "2026-01-01 10:00:00", 'A rename keeps when it was made.');
            tc.verifyEqual(numel(h), 5);
        end

        function buildsColumnsAndVocabulary(tc)
            a = struct('probeDepth', DatasetVariables.entry("Probe Depth", 1200, Units="µm"), 'cohort', DatasetVariables.entry("Cohort", "A"));
            b = struct('probeDepth', DatasetVariables.entry("Probe Depth", 900, Units="µm"));
            T = DatasetVariables.columns({a, struct(), b});
            tc.verifyEqual(T.Properties.VariableNames, {'var_probeDepth', 'var_cohort'});
            tc.verifyEqual(T.var_probeDepth, [1200; NaN; 900]);
            tc.verifyEqual(T.var_cohort(1), "A"); tc.verifyTrue(all(ismissing(T.var_cohort(2:3))));
            tc.verifyEqual(T.Properties.VariableUnits, {'µm', ''});
            tc.verifyEqual(T.Properties.VariableDescriptions, {'Probe Depth', 'Cohort'});
            T = DatasetVariables.columns({a, b}, Rows=[2 2 1]);
            tc.verifyEqual(T.var_probeDepth, [900; 900; 1200], 'Rows= repeats each set''s row.');
            T = DatasetVariables.columns({DatasetVariables.info(a), b});
            tc.verifyEqual(T.var_probeDepth, [1200; 900], 'An info table is taken for a set.');
            T = DatasetVariables.columns({struct(), struct()});
            tc.verifyEqual(size(T), [2 0]);
            V = DatasetVariables.vocabulary({a, b, struct('cohort', DatasetVariables.entry("Cohort", 3))});
            tc.verifyEqual(string({V.name}), ["probeDepth" "cohort"]);
            tc.verifyEqual([V.count], [2 2]);
            tc.verifyEqual(V(2).type, "mixed");
            tc.verifyEqual(DatasetVariables.values(a), struct('probeDepth', 1200, 'cohort', "A"));
            tc.verifyEqual(DatasetVariables.toText(a), "probeDepth = 1200 µm; cohort = A");
            tc.verifyEqual(DatasetVariables.fromInfo(DatasetVariables.info(a)), DatasetVariables.require(a));
        end

        function parsesWhatAFileHolds(tc)
            raw = struct('ok', struct('label', 'OK', 'value', 3), 'bad', struct('label', '', 'value', 1), ...
                'list', struct('label', 'L', 'value', [1; 2]), 'txt', struct('label', 'T', 'value', 'x'));
            [s, bad] = DatasetVariables.parse(raw);
            tc.verifyEqual(DatasetVariables.names(s), ["ok" "txt"]);
            tc.verifyEqual(bad, ["bad" "list"]);
            tc.verifyEqual(s.txt.value, "x", 'Text comes back as a string.');
            tc.verifyEqual(DatasetVariables.parse([]), struct());
            h = DatasetVariables.parseHistory({struct('time', '2026-01-01 10:00:00', 'action', 'created', 'name', 'ok', 'value', 3), ...
                struct('time', '', 'action', 'created', 'name', 'x'), struct('time', 't', 'action', 'eaten', 'name', 'x')});
            tc.verifyEqual(numel(h), 1, 'Rows without a time or with an unknown action are left out.');
        end

        function writesAFileFolderOrDataset(tc)
            tc.Ds.writeManifest();
            f = tc.Ds.manifestFile();
            [s, a] = writeManifestVariables(f, Name="probeDepth", Value=1200, Label="Probe Depth", Units="µm", Description="tip");
            tc.verifyEqual(a.action, "created");
            tc.verifyEqual(s.probeDepth.value, 1200);
            m = EphysDataset.readManifest(f);
            tc.verifyEqual(string(m.variables.probeDepth.units), "µm", 'µ survives the file.');
            [~, a] = writeManifestVariables(tc.Dir, Name="probeDepth", Value=1250);
            tc.verifyEqual(a.action, "updated");
            m = EphysDataset.readManifest(f);
            tc.verifyEqual(string(m.variables.probeDepth.label), "Probe Depth", 'An update keeps the label not given.');
            txt = fileread(f);
            [~, a] = writeManifestVariables(f, Name="probeDepth", Value=1250);
            tc.verifyEmpty(a);
            tc.verifyEqual(fileread(f), txt, 'A request that changes nothing writes nothing.');
            s = writeManifestVariables(f, Name="dose", Value="none");
            tc.verifyEqual(s.dose.label, "Dose", 'A label made from the name.');
            writeManifestVariables(f, Remove=["dose" "notThere"]);
            h = DatasetVariables.parseHistory(EphysDataset.readManifest(f).variable_history);
            tc.verifyEqual([h.action], ["created" "updated" "created" "removed"]);
            tc.verifyTrue(contains(fileread(f), '"changed": ['), 'One changed field is still a list.');
            tc.verifyFalse(contains(extractAfter(string(fileread(f)), '"variable_history"'), '"value":'), ...
                'Only the latest value is in the manifest: the history holds none.');
            % the dataset object
            tc.Ds.applyManifest();
            tc.verifyEqual(DatasetVariables.names(tc.Ds.Variables), "probeDepth");
            tc.verifyEqual(numel(tc.Ds.VariableHistory), 4);
            writeManifestVariables(tc.Ds, Set=struct('depth', tc.Ds.Variables.probeDepth), Renamed=["probeDepth" "depth"]);
            tc.verifyEqual(tc.Ds.VariableHistory(end).action, "renamed");
            m = EphysDataset.readManifest(f);
            tc.verifyTrue(isfield(m.variables, 'depth') && ~isfield(m.variables, 'probeDepth'));
        end

        function changesOnlyTheVariablesAndTheTime(tc)
            tc.Ds.Tags = {'ofc'};
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, surgeon="DS");
            f = tc.Ds.manifestFile();
            m0 = EphysDataset.readManifest(f);
            writeManifestVariables(f, Name="probeDepth", Value=1200);
            m = EphysDataset.readManifest(f);
            tc.verifyEqual(rmfield(m, {'variables', 'variable_history', 'updated'}), ...
                rmfield(m0, intersect({'variables', 'variable_history', 'updated'}, fieldnames(m0))), ...
                'Every other field stays, the tags and the custom block too.');
        end

        function refusesBadRequests(tc)
            tc.Ds.writeManifest();
            f = tc.Ds.manifestFile();
            txt = fileread(f);
            tc.verifyError(@() writeManifestVariables(f, Name="probe depth", Value=1), 'DatasetVariables:BadName');
            tc.verifyError(@() writeManifestVariables(f, Name="x", Value=NaN), 'DatasetVariables:BadValue');
            tc.verifyError(@() writeManifestVariables(f), 'writeManifestVariables:BadInput');
            tc.verifyError(@() writeManifestVariables(f, Set=struct(), Remove="x"), 'writeManifestVariables:BadInput');
            tc.verifyError(@() writeManifestVariables(fullfile(tc.Dir, "nope.json"), Name="x", Value=1), 'writeManifestVariables:NotFound');
            tc.verifyEqual(fileread(f), txt, 'Nothing was written.');
            bad = fullfile(tc.Dir, "other_manifest.json");
            writelines("not json", bad);
            tc.verifyError(@() writeManifestVariables(tc.Dir, Name="x", Value=1), 'writeManifestVariables:Ambiguous');
            tc.verifyError(@() writeManifestVariables(bad, Name="x", Value=1), 'writeManifestVariables:Unreadable');
        end

        function roundTripsThroughTheDataset(tc)
            s = struct('probeDepth', DatasetVariables.entry("Probe Depth", 1200, Units="µm"), 'code', DatasetVariables.entry("Code", "007"));
            a = tc.Ds.setVariables(s);
            tc.verifyEqual([a.action], ["created" "created"]);
            tc.verifyTrue(tc.Ds.writeManifest());
            d2 = EphysDataset(tc.Dir, AutoMetadata=false, Name="subjA_260101_120000");
            d2.applyManifest();
            tc.verifyEqual(d2.Variables, tc.Ds.Variables);
            tc.verifyEqual(d2.VariableHistory, tc.Ds.VariableHistory);
            tc.verifyEqual(d2.Variables.code.value, "007", 'Text that looks like a number stays text.');
            tc.verifyError(@() tc.Ds.setVariables(struct('bad', struct('label', "", 'value', 1))), 'DatasetVariables:BadLabel');
            tc.verifyEqual(tc.Ds.Variables, d2.Variables, 'An error changes nothing.');
        end

        function mergesAnotherWritersChanges(tc)
            tc.Ds.setVariables(struct('a', DatasetVariables.entry("A", 1), 'b', DatasetVariables.entry("B", 2)));
            tc.Ds.writeManifest();
            f = tc.Ds.manifestFile();
            pause(1.1);   % the stamp is the "updated" second and the size
            writeManifestVariables(f, Name="c", Value=3);           % another session adds c
            writeManifestVariables(f, Name="b", Value=20);          % and changes b
            s = tc.Ds.Variables;
            s.a.value = 10;                                          % this object changes a
            tc.Ds.setVariables(s);
            tc.verifyTrue(tc.Ds.writeManifest());
            m = EphysDataset.readManifest(f);
            v = DatasetVariables.values(DatasetVariables.parse(m.variables));
            tc.verifyEqual(v, struct('a', 10, 'b', 20, 'c', 3), 'Each writer''s change is kept, variable by variable.');
            h = DatasetVariables.parseHistory(m.variable_history);
            tc.verifyEqual(numel(h), 5, 'The history holds the rows of both.');
            tc.verifyEqual(h(end).name, "a");
            % an object that never read the file keeps the file's variables
            d3 = EphysDataset(tc.Dir, AutoMetadata=false, Name="subjA_260101_120000");
            tc.verifyTrue(d3.writeManifest());
            m = EphysDataset.readManifest(f);
            tc.verifyEqual(numel(fieldnames(m.variables)), 3);
        end
    end
end
