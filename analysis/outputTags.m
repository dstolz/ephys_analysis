function tags = outputTags(out)
%outputTags  A dataset's tags from its manifest, without loading a source.
%   TAGS = outputTags(OUT) for a DatasetOutputs reads the manifest's tags
%   key (TagSet.parse) and returns the tag set: a 1 x N cellstr, sorted,
%   lowercase; {} when the manifest has no tags, there is no manifest or
%   it cannot be read. It is what loadAnalysisSource puts in SRC.tags,
%   for callers that list many datasets and must not load each one's
%   events (the Data tab, EphysAnalysisRunner.sessionTable). The manifest
%   is read once per DatasetOutputs with CacheData.
%
%   See also loadAnalysisSource, TagSet, DatasetOutputs.

arguments
    out (1,1) DatasetOutputs
end

tags = {};
try
    if out.has("manifest")
        m = out.Manifest;
        if isfield(m, 'tags'); tags = TagSet.parse(m.tags); end
    end
catch   % an unreadable manifest: no tags (loadAnalysisSource warns about it)
end
end
