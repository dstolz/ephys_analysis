function vars = outputVariables(out)
%outputVariables  A dataset's variables from its manifest, without loading a source.
%   VARS = outputVariables(OUT) for a DatasetOutputs reads the manifest's
%   variables key (DatasetVariables.parse) and returns the set: a struct
%   with a field per variable, each an entry (label, value, units,
%   description, created, updated); struct() when the manifest has no
%   variables, there is no manifest or it cannot be read. DatasetVariables
%   .values(VARS) gives the values alone (VARS.probeDepth = 1200) and
%   DatasetVariables.columns({VARS1, VARS2, ...}) a table column per
%   variable. It is what loadAnalysisSource puts in SRC.variables and
%   SRC.variableInfo, for callers that list many datasets and must not
%   load each one's events (the Data tab, EphysAnalysisRunner.sessionTable).
%   The manifest is read once per DatasetOutputs with CacheData.
%
%   See also outputTags, loadAnalysisSource, DatasetVariables, DatasetOutputs.

arguments
    out (1,1) DatasetOutputs
end

vars = struct();
try
    if out.has("manifest")
        m = out.Manifest;
        if isfield(m, 'variables'); vars = DatasetVariables.parse(m.variables); end
    end
catch   % an unreadable manifest: no variables (loadAnalysisSource warns about it)
end
end
