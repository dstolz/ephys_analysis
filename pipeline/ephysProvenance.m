function p = ephysProvenance(opts)
%ephysProvenance  What an output records about the code and the run that wrote it.
%   P = ephysProvenance() returns a struct with
%     software    "ephys_analysis"
%     version     the release number (ephysVersion: the VERSION file)
%     commit      the git commit checked out ("" when git cannot tell)
%     branch      its branch ("" when detached or unknown)
%     dirty       true when tracked files had uncommitted changes, so the
%                 commit alone does not reproduce the code
%     describe    git describe --tags --always --dirty
%     code        all of it on one line (ephysVersion().Text)
%     matlab      MATLAB's version string; platform (computer), host, user
%     created     when P was made, yyyy-MM-ddTHH:mm:ss
%     runId       the pipeline run that wrote the output ("" outside a run)
%     configFile  the pipeline config's file ("" when none or not saved)
%     config      the pipeline config that drove the run, as a plain struct
%                 (EphysPipelineConfig.toStruct; struct([]) when none):
%                 EphysPipelineConfig.fromStruct(P.config) rebuilds it
%
%   P = ephysProvenance(Config=CFG, RunId=ID) fills config, configFile and
%   runId (EphysPipeline.run passes them to every writer).
%
%   Every output writer stores P: the .mat files in their conversion or
%   export struct (field provenance), the JSON ones (the .bin sidecar,
%   settings.json, the kCSD meta, run records) as an object with
%   non-finite numbers written as strings (provenanceForJson).
%
%   See also ephysVersion, EphysPipeline.run, provenanceForJson.

arguments
    opts.Config = []
    opts.RunId (1,1) string = ""
end

v = ephysVersion();
p = struct();
p.software = "ephys_analysis";
p.version = v.Version;
p.commit = v.Commit;
p.branch = v.Branch;
p.dirty = v.Dirty;
p.describe = v.Describe;
p.code = v.Text;
p.matlab = string(version);
p.platform = string(computer);
p.host = hostName();
p.user = userName();
p.created = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
p.runId = opts.RunId;
p.configFile = "";
p.config = struct([]);
if ~isempty(opts.Config)
    if isa(opts.Config, 'EphysPipelineConfig')
        p.configFile = string(opts.Config.File);
        p.config = opts.Config.toStruct();
    elseif isstruct(opts.Config)
        p.config = opts.Config;
    else
        error('ephysProvenance:BadConfig', 'Config must be an EphysPipelineConfig or a struct.');
    end
end
end


function h = hostName()
h = string(getenv('COMPUTERNAME'));
if h == ""; h = string(getenv('HOSTNAME')); end
if h == ""
    [st, out] = system('hostname');
    if st == 0; h = strtrim(string(out)); end
end
end


function u = userName()
u = string(getenv('USERNAME'));
if u == ""; u = string(getenv('USER')); end
end
