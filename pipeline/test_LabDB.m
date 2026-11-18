classdef test_LabDB < matlab.unittest.TestCase
    %test_LabDB  This toolbox's side of the shared lab database client: LabBridge and the hooks it registers.
    %   The client itself (settings, vault, storage roots, connection, window,
    %   lamp, outbox, sending) lives in the CarasLabDB repository's +labclient
    %   package and is tested there (tests/matlab/LabClientTests.m). What is
    %   tested here is what this toolbox adds: the bridge's door to the
    %   package, the session-file hooks it registers under the name
    %   ephys_analysis, the hand-over of the test preference store to the
    %   client, the take-over of the settings and outbox of the time before the
    %   client was shared, and the lamp.
    %
    %   Everything runs in a temporary preference store, a fake password vault
    %   and a temporary client folder: no server, nothing of the user's touched.
    %
    %   Usage:  runtests("test_LabDB")

    properties (Access = private)
        Restore = {}
    end

    methods (TestMethodSetup)
        function isolate(tc)
            tc.Restore = {AppPrefs.useTemporary(), labclient.Secrets.useFake(), labclient.DB.useTemporary(), ...
                labclient.Sync.useManual()};
            tc.addTeardown(@() tc.clearRestore());
        end
    end

    methods (Access = private)
        function clearRestore(tc)
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
        end
    end

    methods (Test)
        function theClientIsThere(tc)
            tc.verifyTrue(LabBridge.available());
            tc.verifyTrue(LabBridge.recentEnough(), "the package is the version this toolbox is written for");
            tc.verifyFalse(LabBridge.recentEnough(labclient.Api.Version + 1), "a later version than the package has is not there");
            tc.verifyEqual(LabBridge.Tool, "ephys_analysis");
            tc.verifyFalse(LabCapture.enabled(), "off until set up");
            s = labclient.Settings.defaults();
            s.Enabled = true; s.Server = "labdb.test"; s.Username = "jdoe";
            labclient.Settings.save(s);
            tc.verifyTrue(LabCapture.enabled(), "on once set up (CarasLabDB is on the path)");
        end

        function enabledRegistersTheHooks(tc)
            labclient.Sync.unregisterTool(LabBridge.Tool);
            tc.verifyFalse(labclient.Sync.hasTool("ephys_analysis"));
            s = labclient.Settings.defaults();
            s.Enabled = true; s.Server = "labdb.test"; s.Username = "jdoe";
            labclient.Settings.save(s);
            tc.verifyTrue(LabCapture.enabled());
            tc.verifyTrue(labclient.Sync.hasTool("ephys_analysis"), "the first time it is true");
            tc.verifyEqual(labclient.Sync.untaggedTool(), LabBridge.Tool, ...
                "the records that name no tool are this toolbox's: it wrote them");
            tc.verifyTrue(labclient.Sync.hasTool(labclient.Bundles.Untagged), "so they can be sent from here");
            h = labclient.Sync.hooks("ephys_analysis");
            top = string(tempname);
            mkdir(top);
            tc.addTeardown(@() rmdir(top, "s"));
            ses = h.readSession(top, "x");
            tc.verifyEqual(ses.session_id, "", "no session file: no id");
            tc.verifyEqual(ses.subject_id, "");
        end

        function theHooksReadAndWriteTheSessionFile(tc)
            top = string(tempname);
            mkdir(top);
            tc.addTeardown(@() rmdir(top, "s"));
            name = "G-1_260702_141210";
            ses = LabCapture.session(top, name);
            tc.verifyNotEqual(ses.session_id, "");
            LabBridge.registerTool();
            h = labclient.Sync.hooks("ephys_analysis");
            h.assignSubject(top, name, "G-2");
            tc.verifyEqual(string(h.readSession(top, name).subject_id), "G-2");
            other = labclient.Bundles.newId();
            h.copyOfSession(top, name, other, "recording", "");
            tc.verifyEqual(string(h.readSession(top, name).session_id), other, "the folder takes the recording's session");
        end

        function aDatasetRecordNamesThisTool(tc)
            b = labclient.Bundles.event(EventId=labclient.Bundles.newId(), EventType="analysis", ...
                OccurredAt=labclient.Bundles.now(), Dataset=struct("name", "n", "folder", "/f/n", ...
                "session_id", "", "subject_folder_id", "G-1", "recording_start", "", "tool", LabBridge.Tool));
            tc.verifyEqual(labclient.Bundles.toolOf(b), "ephys_analysis");
            old = labclient.Bundles.event(EventId=labclient.Bundles.newId(), EventType="analysis", ...
                OccurredAt=labclient.Bundles.now(), Dataset=struct("name", "n", "folder", "/f/n"));
            tc.verifyEqual(labclient.Bundles.toolOf(old), labclient.Bundles.Untagged, ...
                "a record from before records named their tool: the client assumes none");
            LabBridge.registerTool();
            tc.verifyEqual(labclient.Sync.untaggedTool(), LabBridge.Tool, "this toolbox takes them: it wrote them");
        end

        function theTestPreferenceStoreCarriesToTheClient(tc)
            tc.verifyNotEqual(labclient.Prefs.storeFile(), "", "AppPrefs.useTemporary hands over its file");
            s = labclient.Settings.defaults();
            s.Server = "kept-in-the-file";
            labclient.Settings.save(s);
            tc.verifyEqual(labclient.Settings.load().Server, "kept-in-the-file");
            file = labclient.Prefs.storeFile();
            tc.verifyTrue(isfile(file), "in the temporary file, not in MATLAB's preferences");
            tc.Restore{1} = [];
            tc.verifyFalse(isfile(file), "deleted with the temporary store");
            tc.verifyNotEqual(labclient.Prefs.storeFile(), file, "and the store before it is back");
            tc.Restore{1} = AppPrefs.useTemporary();   % what the teardown expects to clear
        end

        function theEarlierSettingsAndOutboxAreTakenOver(tc)
            old = string(tempname);
            mkdir(fullfile(old, "outbox", "pending"));
            mkdir(fullfile(old, "outbox", "claimed"));
            tc.addTeardown(@() rmdir(old, "s"));
            id1 = labclient.Bundles.newId(); id2 = labclient.Bundles.newId(); id3 = labclient.Bundles.newId();
            writelines("old one", fullfile(old, "outbox", "pending", id1 + ".json"));
            writelines("old two", fullfile(old, "outbox", "pending", id2 + ".json"));
            writelines("busy", fullfile(old, "outbox", "claimed", id3 + ".json"));
            % one of them is in the client's outbox already: never overwritten
            mkdir(fullfile(labclient.DB.folder(), "outbox", "pending"));
            writelines("new two", fullfile(labclient.DB.folder(), "outbox", "pending", id2 + ".json"));
            s = labclient.Settings.defaults();
            s.Server = "from-the-old-prefs"; s.Username = "jdoe";
            AppPrefs.setpref("LabDB", "Settings", s);
            tc.verifyFalse(labclient.Prefs.ispref(labclient.Settings.Name));

            setenv("EPHYS_LABDB_DIR", char(old));
            tc.addTeardown(@() setenv("EPHYS_LABDB_DIR", ""));
            LabBridge.migrate(Force=true);
            tc.verifyEqual(labclient.Settings.load().Server, "from-the-old-prefs", "settings copied");
            dest = labclient.DB.folder();
            tc.verifyEqual(strtrim(string(fileread(fullfile(dest, "outbox", "pending", id1 + ".json")))), "old one", "moved");
            tc.verifyFalse(isfile(fullfile(old, "outbox", "pending", id1 + ".json")));
            tc.verifyEqual(strtrim(string(fileread(fullfile(dest, "outbox", "pending", id2 + ".json")))), "new two", "never overwritten");
            tc.verifyTrue(isfile(fullfile(old, "outbox", "pending", id2 + ".json")), "the one not moved stays");
            tc.verifyTrue(isfile(fullfile(old, "outbox", "claimed", id3 + ".json")), "what is being sent is left");
            log = string(fileread(fullfile(dest, "migration_from_ephys_analysis.log")));
            tc.verifySubstring(log, "1 moved");
            tc.verifySubstring(log, "settings");

            % done once: the log's presence says so
            writelines("old four", fullfile(old, "outbox", "pending", "x.json"));
            LabBridge.migrate(Force=true);
            tc.verifyFalse(isfile(fullfile(dest, "outbox", "pending", "x.json")));
        end

        function theLampIsTheClientsLamp(tc)
            f = uifigure("Visible", "off");
            tc.addTeardown(@() delete(f));
            g = uigridlayout(f, [1 2]);
            labclient.DB.disconnect();   % the state the (empty) settings give
            LabBridge.lamp(g, Row=1, Column=2, Parent=f);
            b = findobj(f, "Tag", "LabClientLamp");
            tc.verifyEqual(string(b.Text), "Database: off");
        end

        function theStampsDoNotNeedTheGoldenPath(tc)
            % what every step stamps, from the bridge: the same shapes the client gives
            tc.verifyNotEmpty(regexp(LabBridge.newId(), '^[0-9a-f]{8}-[0-9a-f]{4}-4', 'once'));
            f = string(fullfile(tempname));
            writelines("abc", f);
            tc.addTeardown(@() delete(f));
            it = LabBridge.item(f, Role="derived", Kind="x");
            tc.verifyEqual(sort(string(fieldnames(it))), sort(string(fieldnames(labclient.Bundles.noItems()))));
            tc.verifyEqual(LabBridge.sha256(f), labclient.fileSha256(f));
            tc.verifyTrue(LabBridge.sameSnapshot(LabBridge.snapshot(f), LabBridge.snapshot(f)));
        end
    end
end
