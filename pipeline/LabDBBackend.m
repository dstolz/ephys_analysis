classdef (Abstract) LabDBBackend < handle
    % LabDBBackend  What the toolbox asks of the lab database: the one seam to CarasLabDB.
    %   LabDB talks to the database only through these methods. The real
    %   backend is LabDBCarasBackend (the CarasLabDB class, Database
    %   Toolbox); the tests use LabDBFakeBackend, which keeps the same
    %   rules in memory, so every path is tested without a server.
    %
    %     [ok, why] = b.probe(s)     % is the server there? (quick; nothing opened)
    %     b.open(s, password)        % connect (errors say why)
    %     tf = b.isOpen()
    %     b.close()
    %     p = b.person()             % struct: PersonId, Login
    %     T = b.storageRoots()       % root_id, name, description
    %     id = b.addStorageRoot(name, description)
    %     T = b.sessions(filters)    % filters: struct of SubjectId, StorageRootId, RelativePath, ...
    %     T = b.artifacts(filters)   % filters: struct of SessionId, StorageRootId, RelativePath,
    %                                %   PathPrefix, PresentOnly, ...
    %
    %   S is the LabDBSettings struct. Errors whose identifier ends in
    %   ":Unreachable" mean the server could not be reached; any other
    %   error means it answered and refused.
    %
    %   See also LabDB, LabDBCarasBackend, LabDBFakeBackend.

    methods (Abstract)
        [ok, why] = probe(obj, s)
        open(obj, s, password)
        tf = isOpen(obj)
        close(obj)
        p = person(obj)
        T = storageRoots(obj)
        id = addStorageRoot(obj, name, description)
        T = sessions(obj, filters)
        T = artifacts(obj, filters)
    end
end
