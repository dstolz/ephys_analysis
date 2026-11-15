classdef LabOutbox
    % LabOutbox  What waits on this computer to be sent to the lab database: one file per record.
    %   Every record for the database is written here first (LabCapture), so
    %   nothing is lost while the server is out of reach, MATLAB closes or
    %   the computer restarts. The outbox is the folder "outbox" in
    %   LabDB.folder(), one subfolder per state:
    %
    %     pending   waiting to be sent (an unsealed one still waits for the
    %               SHA-256 of an output, LabHasher)
    %     claimed   being sent by one MATLAB; a heartbeat file says which
    %               and when it last showed life
    %     held      waiting for a person (a file that changed after it was
    %               captured, a subject to assign, ...); the note says why
    %     failed    the database refused it; the note gives its reason
    %     done      sent (kept as a local log)
    %     discarded put aside by a person, never to be sent (kept, with who
    %               and why)
    %
    %   A bundle is <bundle_id>.json (LabBundles); a note beside it,
    %   <bundle_id>.note.json, says when and why it moved. Files are written
    %   to a temporary name and renamed into place, so a crash never leaves
    %   half a file. A claim is a rename, which only one process can win.
    %
    %     LabOutbox.put(b)                    % a new bundle, pending
    %     [b, state] = LabOutbox.read(id)
    %     LabOutbox.update(b)                 % rewrite a pending or claimed bundle
    %     T = LabOutbox.list(State="pending") % id, state, type, captured_at, sealed, note
    %     n = LabOutbox.counts()              % one count per state
    %     claim = LabOutbox.claim(id)         % [] when another process has it
    %     LabOutbox.heartbeat(claim)
    %     LabOutbox.finish(claim, "done" | "failed" | "held" | "pending", Reason=, Flags=)
    %     LabOutbox.move(id, state, Reason=, Flags=)  % hold, release, retry, discard
    %     n = LabOutbox.recoverStale(MaxAge=120)
    %
    %   See also LabBundles, LabCapture, LabHasher, LabDB.folder.

    properties (Constant)
        States = ["pending" "claimed" "held" "failed" "done" "discarded"]
    end

    methods (Static)
        function d = root()
            %root  The outbox folder (each state's subfolder created when missing).
            d = string(fullfile(LabDB.folder(), "outbox"));
            for s = LabOutbox.States
                f = fullfile(d, s);
                if ~isfolder(f); mkdir(f); end
            end
        end

        function f = file(id, state)
            %file  Where bundle ID lives in STATE.
            f = string(fullfile(LabOutbox.root(), state, LabOutbox.checkId(id) + ".json"));
        end

        function put(b)
            %put  Write the new bundle B as pending.
            %   A bundle of the same id already here with the same text is
            %   left as it is; one with other text is LabOutbox:Exists.
            id = LabOutbox.checkId(b.bundle_id);
            txt = LabBundles.encode(b);
            [old, state] = LabOutbox.readText(id);
            if state ~= ""
                if old == txt; return; end
                error("LabOutbox:Exists", "A different bundle %s is already in the outbox (%s).", id, state);
            end
            writeJsonFile(LabOutbox.file(id, "pending"), txt, Text=true);
        end

        function [b, state] = read(id)
            %read  Bundle ID and its state ([] and "" when it is not here).
            [txt, state] = LabOutbox.readText(id);
            b = [];
            if state == ""; return; end
            b = LabBundles.decode(txt);
        end

        function update(b)
            %update  Rewrite bundle B where it is (pending or claimed), e.g. with a hash added.
            id = LabOutbox.checkId(b.bundle_id);
            [~, state] = LabOutbox.readText(id);
            if ~ismember(state, ["pending" "claimed" "held"])
                error("LabOutbox:State", "Bundle %s cannot be changed: it is %s.", id, ...
                    LabOutbox.stateWord(state));
            end
            writeJsonFile(LabOutbox.file(id, state), LabBundles.encode(b), Text=true);
        end

        function T = list(opts)
            %list  The bundles in STATE (all states when "") as a table, oldest capture first.
            %   Columns: id, state, type, captured_at, sealed, file, note (why
            %   it is held or failed, "" for none).
            arguments
                opts.State (1,1) string = ""
            end
            states = LabOutbox.States;
            if opts.State ~= ""; states = opts.State; end
            id = strings(0, 1); st = id; ty = id; at = id; fl = id; nt = id; sealed = false(0, 1);
            for s = states
                d = LabOutbox.bundleFiles(s);
                for k = 1:numel(d)
                    f = string(fullfile(d(k).folder, d(k).name));
                    try
                        b = LabBundles.decode(fileread(f));
                    catch
                        continue   % not a bundle: left alone
                    end
                    id(end+1, 1) = b.bundle_id; %#ok<AGROW>
                    st(end+1, 1) = s; %#ok<AGROW>
                    ty(end+1, 1) = b.type; %#ok<AGROW>
                    at(end+1, 1) = b.captured_at; %#ok<AGROW>
                    sealed(end+1, 1) = LabBundles.isSealed(b); %#ok<AGROW>
                    fl(end+1, 1) = f; %#ok<AGROW>
                    n = LabOutbox.note(b.bundle_id, s);
                    nt(end+1, 1) = n.reason; %#ok<AGROW>
                end
            end
            T = table(id, st, ty, at, sealed, fl, nt, ...
                'VariableNames', {'id', 'state', 'type', 'captured_at', 'sealed', 'file', 'note'});
            T = sortrows(T, 'captured_at');
        end

        function c = counts()
            %counts  The number of bundles in each state, as a struct.
            c = struct();
            for s = LabOutbox.States
                c.(s) = numel(LabOutbox.bundleFiles(s));
            end
        end

        function n = note(id, state)
            %note  The note of bundle ID in STATE: state, reason, at, host ("" each when none), flags.
            %   FLAGS (a string row) are what a person decided for it, e.g.
            %   "on_behalf" (send it although another login captured it).
            n = struct("state", "", "reason", "", "at", "", "host", "", "flags", strings(1, 0));
            f = fullfile(LabOutbox.root(), state, LabOutbox.checkId(id) + ".note.json");
            if ~isfile(f); return; end
            x = readJsonFile(f, ErrorOnFail=false);
            if ~isstruct(x); return; end
            for k = ["state" "reason" "at" "host"]
                if isfield(x, k); n.(k) = string(x.(k)); end
            end
            if isfield(x, "flags") && ~isempty(x.flags)
                n.flags = reshape(string(x.flags), 1, []);
            end
        end

        function c = claim(id)
            %claim  Take pending bundle ID for this MATLAB to send; [] when it is not pending (another process has it).
            id = LabOutbox.checkId(id);
            src = LabOutbox.file(id, "pending");
            dst = LabOutbox.file(id, "claimed");
            c = [];
            if ~isfile(src); return; end
            [ok, ~] = movefile(src, dst);
            if ~ok || ~isfile(dst); return; end
            LabOutbox.moveNote(id, "pending", "claimed");
            c = struct("id", id, "host", LabBundles.host(), "pid", LabOutbox.pid(), ...
                "claimed_at", LabBundles.now());
            LabOutbox.heartbeat(c);
        end

        function heartbeat(claim)
            %heartbeat  Say that the claim is still being worked on.
            hb = claim;
            hb.beat_at = LabBundles.now();
            writeJsonFile(fullfile(LabOutbox.root(), "claimed", claim.id + ".claim.json"), hb);
        end

        function finish(claim, state, opts)
            %finish  End a claim: the bundle goes to STATE (done, failed, held or back to pending).
            arguments
                claim (1,1) struct
                state (1,1) string {mustBeMember(state, ["done" "failed" "held" "pending"])}
                opts.Reason (1,1) string = ""
                opts.Flags (1,:) string = string(missing)   % replace the flags (default: keep them)
            end
            flags = LabOutbox.flagsFor(claim.id, "claimed", opts.Flags);
            LabOutbox.moveTo(claim.id, "claimed", state, opts.Reason, flags);
            hb = fullfile(LabOutbox.root(), "claimed", claim.id + ".claim.json");
            if isfile(hb); delete(hb); end
        end

        function move(id, state, opts)
            %move  Move bundle ID (not claimed) to STATE: hold it, release it, retry a failed one.
            arguments
                id (1,1) string
                state (1,1) string {mustBeMember(state, ["pending" "held" "failed" "done" "discarded"])}
                opts.Reason (1,1) string = ""
                opts.Flags (1,:) string = string(missing)   % replace the flags (default: keep them)
            end
            [~, from] = LabOutbox.readText(id);
            if from == ""
                error("LabOutbox:Missing", "Bundle %s is not in the outbox.", id);
            elseif from == "claimed"
                error("LabOutbox:State", "Bundle %s is being sent; it cannot be moved now.", id);
            end
            keep = isscalar(opts.Flags) && ismissing(opts.Flags);
            if from == state && keep; return; end
            LabOutbox.moveTo(LabOutbox.checkId(id), from, state, opts.Reason, ...
                LabOutbox.flagsFor(id, from, opts.Flags));
        end

        function n = recoverStale(opts)
            %recoverStale  Give back claims whose heartbeat is older than MaxAge seconds (their MATLAB stopped).
            arguments
                opts.MaxAge (1,1) double {mustBePositive} = 120
            end
            n = 0;
            d = LabOutbox.bundleFiles("claimed");
            nowT = datetime("now", "TimeZone", "local");
            for k = 1:numel(d)
                id = string(erase(d(k).name, ".json"));
                hbFile = fullfile(d(k).folder, id + ".claim.json");
                beat = NaT("TimeZone", "local");
                if isfile(hbFile)
                    hb = readJsonFile(hbFile, ErrorOnFail=false);
                    if isstruct(hb) && isfield(hb, "beat_at")
                        try
                            beat = datetime(string(hb.beat_at), "InputFormat", LabBundles.TimeFormat, ...
                                "TimeZone", "local");
                        catch
                        end
                    end
                end
                if isnat(beat)
                    dt = datetime(d(k).datenum, "ConvertFrom", "datenum", "TimeZone", "local");
                    beat = dt;   % no heartbeat: the claim's own time
                end
                if seconds(nowT - beat) > opts.MaxAge
                    LabOutbox.moveTo(id, "claimed", "pending", "claim given back: its MATLAB stopped");
                    if isfile(hbFile); delete(hbFile); end
                    n = n + 1;
                end
            end
        end
    end

    methods (Static, Access = private)
        function id = checkId(id)
            id = lower(string(id));
            if isempty(regexp(char(id), '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'once'))
                error("LabOutbox:BadId", "'%s' is not a bundle id (a uuid).", id);
            end
        end

        function d = bundleFiles(state)
            %bundleFiles  The bundle files in STATE's folder (not the notes and heartbeats).
            d = dir(fullfile(LabOutbox.root(), state, "*.json"));
            d = d(~endsWith({d.name}, [".note.json" ".claim.json"]));
        end

        function [txt, state] = readText(id)
            id = LabOutbox.checkId(id);
            txt = "";
            state = "";
            for s = LabOutbox.States
                f = fullfile(LabOutbox.root(), s, id + ".json");
                if isfile(f)
                    txt = string(fileread(f));
                    state = s;
                    return
                end
            end
        end

        function moveTo(id, from, to, reason, flags)
            if nargin < 5; flags = strings(1, 0); end
            old = fullfile(LabOutbox.root(), from, id + ".note.json");
            if from ~= to
                src = LabOutbox.file(id, from);
                dst = LabOutbox.file(id, to);
                [ok, msg] = movefile(src, dst);
                if ~ok
                    error("LabOutbox:Move", "Bundle %s could not be moved from %s to %s: %s", id, from, to, msg);
                end
            end
            if isfile(old); delete(old); end
            n = struct("state", to, "reason", reason, "at", LabBundles.now(), "host", LabBundles.host(), ...
                "flags", {cellstr(flags)});
            writeJsonFile(fullfile(LabOutbox.root(), to, id + ".note.json"), n);
        end

        function f = flagsFor(id, state, given)
            %flagsFor  GIVEN, or the flags of the note bundle ID has in STATE when GIVEN is missing.
            if isscalar(given) && ismissing(given)
                n = LabOutbox.note(id, state);
                f = n.flags;
            else
                f = given;
            end
        end

        function moveNote(id, from, to)
            src = fullfile(LabOutbox.root(), from, id + ".note.json");
            if isfile(src)
                movefile(src, fullfile(LabOutbox.root(), to, id + ".note.json"));
            end
        end

        function p = pid()
            try
                p = double(feature('getpid'));
            catch
                p = NaN;
            end
        end

        function w = stateWord(state)
            if state == ""; w = "not in the outbox"; else; w = state; end
        end
    end
end
