classdef LabDBFakeVault < handle
    % LabDBFakeVault  The in-memory password store LabDBSecrets.useFake switches to (tests).
    %   See also LabDBSecrets.
    properties
        Active (1,1) logical = false
        Map = containers.Map()
    end
end
