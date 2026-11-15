function r = setProcessing(obj, kind, r, opts)
%setProcessing  Keep R as the record of how output KIND was made (Processing.(KIND)).
%   R = ds.setProcessing(KIND, R, Name=Value) is how every writer stores its
%   record (toBin, toMat, spikesToMat, behaviorToMat, exportNWB, the
%   artifact detection, a sort once it is done). KIND is a field of
%   Processing: artifacts, bin, sorting, signals, spikes, behavior or nwb.
%   Before R takes the place of the earlier record, LabCapture.processing
%   stamps it (event_id, created_at, started_at, performer, code_version)
%   and lists the files it wrote (outputs: path, bytes, mtime,
%   artifact_id, sha256 when known); when the lab database is turned on
%   here, it also writes the record to the outbox for the database
%   (LabOutbox). That never stops the writer: a failure there is a warning
%   (EphysDataset:setProcessing:Capture) and the record is kept as the
%   writer made it.
%
%   A record that is already Processing.(KIND) (the same event_id) is kept
%   as it is, and nothing is captured twice.
%
%   Options
%     StartedAt   when the step started (datetime; unzoned is read in the
%                 lab's time zone)
%     Outputs     the files written (default: the record's file, files or
%                 the files of its results folder)
%     Inputs      the files read (default: by KIND, LabCapture)
%     Provenance  the writer's ephysProvenance (code and machine)
%     Capture     false: stamp the record but write nothing to the outbox
%                 (a record of files written earlier, e.g. a detection read
%                 back from its cache)
%
%   See also LabCapture, LabOutbox, EphysDataset.processingRecord.

arguments
    obj (1,1) EphysDataset
    kind (1,1) string {mustBeMember(kind, ["artifacts" "bin" "sorting" "signals" "spikes" "behavior" "nwb"])}
    r (1,1) struct
    opts.StartedAt (1,1) datetime = NaT
    opts.Outputs = []
    opts.Inputs = []
    opts.Provenance = []
    opts.Capture (1,1) logical = true
end

prev = obj.Processing.(kind);
if isstruct(prev) && isscalar(prev) && isfield(prev, 'event_id') && isfield(r, 'event_id') ...
        && string(r.event_id) ~= "" && string(prev.event_id) == string(r.event_id)
    obj.Processing.(kind) = r;
    return
end
try
    started = opts.StartedAt;
    if isnat(started); started = NaT('TimeZone', 'local'); end
    r = LabCapture.processing(obj, kind, r, StartedAt=started, Outputs=opts.Outputs, ...
        Inputs=opts.Inputs, Provenance=opts.Provenance, Capture=opts.Capture);
catch ME
    warning('EphysDataset:setProcessing:Capture', ...
        'The record of %s for %s was kept, but not prepared for the lab database: %s', kind, obj.Name, ME.message);
end
obj.Processing.(kind) = r;
end
