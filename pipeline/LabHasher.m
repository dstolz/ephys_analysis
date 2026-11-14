classdef LabHasher
    % LabHasher  The SHA-256 of the files a record names, taken without making anyone wait.
    %   The lab database keeps every file with its SHA-256. A file up to
    %   LabDBSettings.HashInProcessMB is hashed in MATLAB (fileSha256) as
    %   soon as it is captured; a larger one by a separate process, so a
    %   pipeline step never waits minutes for its .bin to be hashed:
    %   PowerShell's Get-FileHash on Windows, shasum -a 256 on macOS,
    %   sha256sum on Linux. The job writes its result to a temporary name and
    %   renames it into place, in the outbox's "hashing" folder, so a job
    %   that was stopped leaves no half result and MATLAB can close while it
    %   runs.
    %
    %   A hash is kept only for the bytes that were captured: the file's size
    %   and time must be the same as when the record was captured, before and
    %   after it is hashed. A file that changed in between is not hashed: its
    %   bundle is held (LabOutbox) with the reason, for a person to look at.
    %
    %     [h, why] = LabHasher.hashNow(item)  % in MATLAB, when the snapshot still holds
    %     job = LabHasher.start(item, key)    % out of process
    %     [h, state] = LabHasher.poll(job)    % "running" | "done" | "lost" | "failed"
    %     n = LabHasher.work(Budget=seconds)  % every pending bundle: hash, collect, seal
    %
    %   See also fileSha256, LabOutbox, LabBundles, LabCapture.

    methods (Static)
        function b = limitBytes(s)
            %limitBytes  Files up to this size are hashed in MATLAB.
            if nargin < 1; s = LabDBSettings.load(); end
            b = s.HashInProcessMB * 2^20;
        end

        function [h, why] = hashNow(it)
            %hashNow  SHA-256 of item IT's file in MATLAB, "" with WHY when its snapshot no longer holds.
            h = "";
            why = LabHasher.changed(it);
            if why ~= ""; return; end
            try
                x = fileSha256(it.path);
            catch ME
                why = "could not be hashed: " + string(ME.message);
                return
            end
            why = LabHasher.changed(it);   % changed while it was read: the hash is of no captured bytes
            if why == ""; h = x; end
        end

        function why = changed(it)
            %changed  "" when IT's file has the size and time it was captured with, else why not.
            cur = LabBundles.snapshot(it.path);
            if isnan(cur.bytes)
                why = "is no longer there";
            elseif ~LabBundles.sameSnapshot(cur, it)
                why = sprintf("changed after it was captured (%d bytes, %s; captured as %d bytes, %s)", ...
                    cur.bytes, cur.mtime, it.bytes, it.mtime);
            else
                why = "";
            end
        end

        function job = start(it, key)
            %start  Hash item IT's file in a separate process; KEY names the job (bundle id and output number).
            folder = LabHasher.folder();
            out = string(fullfile(folder, key + ".sha256"));
            tmp = string(fullfile(folder, key + ".partial"));
            log = string(fullfile(folder, key + ".log"));
            if isfile(out); delete(out); end
            job = struct("key", key, "path", it.path, "bytes", it.bytes, "mtime", it.mtime, ...
                "out", out, "started_at", LabBundles.now(), "host", LabBundles.host());
            writeJsonFile(fullfile(folder, key + ".job.json"), job);
            pb = java.lang.ProcessBuilder(LabHasher.command());
            env = pb.environment();
            env.put('LABHASH_FILE', char(it.path));
            env.put('LABHASH_TMP', char(tmp));
            env.put('LABHASH_OUT', char(out));
            pb.redirectErrorStream(true);
            pb.redirectOutput(java.io.File(char(log)));
            p = pb.start();
            LabHasher.processes(key, p);
        end

        function [h, state] = poll(job)
            %poll  The result of JOB: "done" (H the hash), "running", "failed" or "lost" (no process and no result).
            h = "";
            if isfile(job.out)
                txt = strtrim(string(fileread(job.out)));
                tok = regexp(char(txt), '^([0-9a-fA-F]{64})', 'tokens', 'once');
                if isempty(tok)
                    state = "failed";
                else
                    h = string(lower(tok{1}));
                    state = "done";
                end
                return
            end
            p = LabHasher.processes(job.key);
            if ~isempty(p)
                if p.isAlive()
                    state = "running";
                else
                    state = "failed";   % ended without writing a result
                end
                return
            end
            % Started by a MATLAB that has closed since: lost when it has
            % had far longer than the file needs (10 MB/s, plus 10 min).
            started = datetime(job.started_at, "InputFormat", LabBundles.TimeFormat, "TimeZone", "local");
            allow = double(job.bytes) / 10e6 + 600;
            if seconds(datetime("now", "TimeZone", "local") - started) > allow
                state = "lost";
            else
                state = "running";
            end
        end

        function n = work(opts)
            %work  Hash what the pending bundles still need, within Budget seconds; seal those complete.
            %   Small files are hashed here, large ones get a job (one at a
            %   time per file); finished jobs are collected. A file that
            %   changed since it was captured holds its bundle. N is the
            %   number of bundles sealed.
            arguments
                opts.Budget (1,1) double = 10
            end
            n = 0;
            t0 = tic;
            limit = LabHasher.limitBytes();
            T = LabOutbox.list(State="pending");
            for r = 1:height(T)
                if T.sealed(r); continue; end
                b = LabOutbox.read(T.id(r));
                if isempty(b); continue; end
                [b, why, changedAny] = LabHasher.fill(b, limit, t0, opts.Budget);
                if why ~= ""
                    LabOutbox.move(b.bundle_id, "held", Reason=why);
                    continue
                end
                b = LabBundles.seal(b);
                if changedAny || LabBundles.isSealed(b)
                    LabOutbox.update(b);
                end
                if LabBundles.isSealed(b)
                    n = n + 1;
                    LabHasher.clearJobs(b.bundle_id);
                end
                if toc(t0) > opts.Budget; break; end
            end
        end
    end

    methods (Static, Access = private)
        function [b, why, changedAny] = fill(b, limit, t0, budget)
            why = "";
            changedAny = false;
            o = b.record.outputs;
            for k = 1:numel(o)
                if strlength(o(k).sha256) == 64; continue; end
                key = b.bundle_id + "_" + k;
                jobFile = fullfile(LabHasher.folder(), key + ".job.json");
                if isfile(jobFile)
                    job = readJsonFile(jobFile, ErrorOnFail=false);
                    if ~isstruct(job)
                        delete(jobFile);
                        continue
                    end
                    job.out = string(job.out); job.key = string(job.key);
                    job.started_at = string(job.started_at);
                    [h, state] = LabHasher.poll(job);
                    switch state
                        case "done"
                            w = LabHasher.changed(o(k));
                            if w ~= ""
                                why = "Output " + o(k).path + " " + w + ".";
                                return
                            end
                            o(k).sha256 = h;
                            changedAny = true;
                        case {"failed", "lost"}
                            delete(jobFile);   % started again on the next pass
                    end
                    continue
                end
                w = LabHasher.changed(o(k));
                if w ~= ""
                    why = "Output " + o(k).path + " " + w + ".";
                    return
                end
                if o(k).bytes <= limit && toc(t0) <= budget
                    [h, w] = LabHasher.hashNow(o(k));
                    if w ~= ""
                        why = "Output " + o(k).path + " " + w + ".";
                        return
                    end
                    o(k).sha256 = h;
                    changedAny = true;
                elseif o(k).bytes > limit
                    try
                        LabHasher.start(o(k), key);
                    catch ME
                        warning("LabHasher:Start", "Could not start hashing %s: %s", o(k).path, ME.message);
                    end
                end
            end
            b.record.outputs = o;
        end

        function d = folder()
            %folder  Where the out-of-process jobs keep their files.
            d = string(fullfile(LabDB.folder(), "hashing"));
            if ~isfolder(d); mkdir(d); end
        end

        function clearJobs(id)
            d = dir(fullfile(LabHasher.folder(), id + "_*"));
            for k = 1:numel(d)
                delete(fullfile(d(k).folder, d(k).name));
            end
        end

        function c = command()
            if ispc
                script = ['$h = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:LABHASH_FILE).Hash.ToLowerInvariant(); ' ...
                    '[IO.File]::WriteAllText($env:LABHASH_TMP, $h); ' ...
                    'Move-Item -LiteralPath $env:LABHASH_TMP -Destination $env:LABHASH_OUT -Force'];
                enc = matlab.net.base64encode(unicode2native(script, 'UTF-16LE'));
                c = {'powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', ...
                    '-EncodedCommand', enc};
            elseif ismac
                c = {'/bin/sh', '-c', 'shasum -a 256 -- "$LABHASH_FILE" > "$LABHASH_TMP" && mv -f "$LABHASH_TMP" "$LABHASH_OUT"'};
            else
                c = {'/bin/sh', '-c', 'sha256sum -- "$LABHASH_FILE" > "$LABHASH_TMP" && mv -f "$LABHASH_TMP" "$LABHASH_OUT"'};
            end
        end

        function p = processes(key, proc)
            %processes  The process of job KEY started by this MATLAB ([] when none); with PROC, note it.
            persistent map
            if isempty(map); map = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
            key = char(key);
            if nargin > 1
                map(key) = proc;
                p = proc;
                return
            end
            if isKey(map, key)
                p = map(key);
            else
                p = [];
            end
        end
    end
end
