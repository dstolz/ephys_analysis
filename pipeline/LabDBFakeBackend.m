classdef LabDBFakeBackend < LabDBBackend
    % LabDBFakeBackend  An in-memory lab database for the tests: no server, the same answers.
    %   Set Reachable false to stand for a server that does not answer, and
    %   Refuse to a message to make open fail as a server that answers and
    %   refuses would. Tables can be filled directly (Roots, Sessions,
    %   Artifacts); Calls records every method called, in order.
    %
    %     fake = LabDBFakeBackend();
    %     restore = LabDB.useBackend(@() fake);   % LabDB uses it until cleared
    %
    %   See also LabDBBackend, LabDB.

    properties
        Reachable (1,1) logical = true
        Refuse (1,1) string = ""            % open fails with this message (LabDB:Refused)
        Password (1,1) string = "pw"        % the one open accepts
        PersonId (1,1) string = "00000000-0000-4000-8000-0000000000a1"
        Login (1,1) string = "jdoe"
        Roots table = table(zeros(0, 1), strings(0, 1), strings(0, 1), ...
            'VariableNames', {'root_id', 'name', 'description'})
        Sessions table = table()
        Artifacts table = table()
    end

    properties (SetAccess = private)
        Open (1,1) logical = false
        Calls (:,1) string = strings(0, 1)
        Opens (1,1) double = 0
    end

    methods
        function [ok, why] = probe(obj, ~)
            obj.Calls(end+1) = "probe";
            ok = obj.Reachable;
            why = "";
            if ~ok
                why = "the server did not answer (fake)";
            end
        end

        function open(obj, ~, password)
            obj.Calls(end+1) = "open";
            obj.Opens = obj.Opens + 1;
            if ~obj.Reachable
                error("LabDB:Unreachable", "The server did not answer (fake).");
            end
            if obj.Refuse ~= ""
                error("LabDB:Refused", "%s", obj.Refuse);
            end
            if password ~= obj.Password
                error("LabDB:Refused", "password authentication failed (fake)");
            end
            obj.Open = true;
        end

        function tf = isOpen(obj)
            tf = obj.Open && obj.Reachable;
        end

        function close(obj)
            obj.Calls(end+1) = "close";
            obj.Open = false;
        end

        function p = person(obj)
            obj.requireOpen("person");
            p = struct("PersonId", obj.PersonId, "Login", obj.Login);
        end

        function T = storageRoots(obj)
            obj.requireOpen("storageRoots");
            T = obj.Roots;
        end

        function id = addStorageRoot(obj, name, description)
            obj.requireOpen("addStorageRoot");
            if any(obj.Roots.name == string(name))
                error("LabDB:Refused", "duplicate key value violates unique constraint " + ...
                    "storage_root_name_key (fake)");
            end
            id = max([0; obj.Roots.root_id]) + 1;
            obj.Roots = [obj.Roots; table(id, string(name), string(description), ...
                'VariableNames', {'root_id', 'name', 'description'})];
        end

        function T = sessions(obj, filters)
            obj.requireOpen("sessions");
            T = LabDBFakeBackend.filterRows(obj.Sessions, filters);
        end

        function T = artifacts(obj, filters)
            obj.requireOpen("artifacts");
            T = LabDBFakeBackend.filterRows(obj.Artifacts, filters);
        end
    end

    methods (Access = private)
        function requireOpen(obj, what)
            obj.Calls(end+1) = string(what);
            if ~obj.isOpen()
                error("LabDB:Unreachable", "The database connection is not open (fake).");
            end
        end
    end

    methods (Static, Access = private)
        function T = filterRows(T, filters)
            %filterRows  The rows of T whose columns equal each filter (snake_case of the field).
            if isempty(T) || width(T) == 0
                return
            end
            keep = true(height(T), 1);
            for f = reshape(string(fieldnames(filters)), 1, [])
                v = filters.(f);
                col = lower(regexprep(f, '(?<=[a-z])([A-Z])', '_$1'));
                if col == "path_prefix"
                    keep = keep & startsWith(string(T.relative_path), string(v));
                elseif col == "present_only" || col == "active_only"
                    continue
                elseif ismember(col, string(T.Properties.VariableNames))
                    keep = keep & string(T.(col)) == string(v);
                end
            end
            T = T(keep, :);
        end
    end
end
