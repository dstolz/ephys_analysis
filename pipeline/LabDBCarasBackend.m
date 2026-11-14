classdef LabDBCarasBackend < LabDBBackend
    % LabDBCarasBackend  The lab database through the CarasLabDB MATLAB class (Database Toolbox).
    %   The only code of this toolbox that calls CarasLabDB. It needs the
    %   CarasLabDB repository on the MATLAB path (its @CarasLabDB class
    %   folder) and the Database Toolbox; without either, open says so
    %   (LabDB:NoCarasLabDB, LabDB:NoDatabaseToolbox) and the apps go on
    %   working without the database.
    %
    %   See also LabDBBackend, LabDB.

    properties (Constant)
        % The CarasLabDB method this toolbox needs: a CarasLabDB checkout
        % without it is too old.
        RequiredMethod = "recordEvent"
    end

    properties (SetAccess = private)
        Db = []     % the CarasLabDB object while connected
    end

    methods
        function [ok, why] = probe(~, s)
            %probe  Whether the server accepts a TCP connection within ConnectTimeout (tcpclient).
            ok = false;
            why = "";
            if strlength(s.Server) == 0
                why = "no server is set";
                return
            end
            try
                t = tcpclient(char(s.Server), s.Port, "ConnectTimeout", min(s.ConnectTimeout, 10)); %#ok<NASGU>
                clear t
                ok = true;
            catch ME
                why = "the server " + s.Server + ":" + string(s.Port) + " did not answer (" + ...
                    string(ME.message) + ")";
            end
        end

        function open(obj, s, password)
            %open  Connect as the settings' login.
            if ~LabDBCarasBackend.hasClass()
                error("LabDB:NoCarasLabDB", ...
                    "The CarasLabDB class is not on the MATLAB path, or it is too old (it " + ...
                    "has no %s): add a current CarasLabDB checkout to the path.", ...
                    LabDBCarasBackend.RequiredMethod);
            end
            if exist("postgresql") == 0 %#ok<EXIST>
                error("LabDB:NoDatabaseToolbox", ...
                    "The Database Toolbox (postgresql) is not installed.");
            end
            obj.close();
            args = {"Username", s.Username, "Password", password, "Server", s.Server, ...
                "Port", s.Port, "DatabaseName", s.DatabaseName, ...
                "ConnectTimeout", s.ConnectTimeout, "StatementTimeout", s.StatementTimeout};
            if strlength(s.PersonEmail) > 0
                args = [args, {"PersonEmail", s.PersonEmail}];
            end
            try
                obj.Db = CarasLabDB(args{:});
            catch ME
                if ME.identifier == "CarasLabDB:connectionFailed"
                    error("LabDB:Unreachable", "%s", ME.message);
                end
                rethrow(ME);
            end
        end

        function tf = isOpen(obj)
            tf = ~isempty(obj.Db) && isvalid(obj.Db) && obj.Db.isOpen();
        end

        function close(obj)
            if ~isempty(obj.Db) && isvalid(obj.Db)
                delete(obj.Db);
            end
            obj.Db = [];
        end

        function p = person(obj)
            obj.requireOpen();
            login = "";
            try
                T = obj.Db.runQuery("SELECT session_user AS login");
                login = string(T.login(1));
            catch
            end
            p = struct("PersonId", string(obj.Db.CurrentPersonId), "Login", login);
        end

        function T = storageRoots(obj)
            obj.requireOpen();
            T = obj.Db.getStorageRoots();
        end

        function id = addStorageRoot(obj, name, description)
            obj.requireOpen();
            id = double(obj.Db.addStorageRoot(Name=name, Description=description));
        end

        function T = sessions(obj, filters)
            obj.requireOpen();
            args = namedargs2cell(filters);
            T = obj.Db.getSessions(args{:});
        end

        function T = artifacts(obj, filters)
            obj.requireOpen();
            args = namedargs2cell(filters);
            T = obj.Db.getArtifacts(args{:});
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Static)
        function tf = hasClass()
            %hasClass  True when a CarasLabDB class that has RequiredMethod is on the path.
            tf = false;
            try
                tf = any(string(methods("CarasLabDB")) == LabDBCarasBackend.RequiredMethod);
            catch
            end
        end
    end

    methods (Access = private)
        function requireOpen(obj)
            if ~obj.isOpen()
                error("LabDB:Unreachable", "The database connection is not open.");
            end
        end
    end
end
