function [keep, active] = datasetFilter(subject, tagSets, opts)
%datasetFilter  Which datasets pass a subject, tag and text filter.
%   [KEEP, ACTIVE] = datasetFilter(SUBJECT, TAGSETS, Name=Value) returns, for
%   each dataset, whether it passes every filter that is set. SUBJECT is a
%   string column (one subject per dataset, "" when unknown) and TAGSETS a
%   cell array of tag sets, one per dataset (each a cellstr, as TagSet keeps
%   it; {} for none). KEEP is a logical column; ACTIVE is true when any
%   filter is on (a caller shows "showing k of n" only then). Pure: no UI,
%   no files.
%
%   Each option takes a string array or one text of comma-separated values;
%   blank values and "(any)" are ignored, so an option that holds only those
%   is off. Options that are on are combined with AND.
%     Subjects         keep the datasets whose subject is one of these. Case
%                      is ignored; * and ? are wildcards, and a value must
%                      match the whole subject.
%     ExcludeSubjects  then drop the datasets whose subject is one of these
%                      (the same matching).
%     Tags             keep the datasets with these tags (TagSet.matches; a
%                      value that is no valid tag matches nothing).
%     TagMode          "any" (default): at least one of Tags; "all": every
%                      one. Anything else errors TagSet:BadMode.
%     ExcludeTags      drop the datasets that hold any of these tags. A
%                      dataset with no tags is never dropped by it.
%     Search           words separated by white space; each must appear,
%                      ignoring case, in the dataset's Text.
%     Text             the string column Search looks in (default SUBJECT);
%                      a browser passes name, key, subject and tags joined.
%
%   Errors: datasetFilter:BadSize when SUBJECT, TAGSETS and Text differ in
%   length.
%
%   Example:
%     keep = datasetFilter(["M1"; "M2"; "F3"], {{'pilot'}, {}, {'draft'}}, ...
%         Subjects="M*", ExcludeTags="pilot");   % [false; true; false]
%
%   See also TagSet, subjectAndDate.

arguments
    subject (:,1) string
    tagSets cell
    opts.Subjects = ""
    opts.ExcludeSubjects = ""
    opts.Tags = ""
    opts.TagMode (1,1) string = "any"
    opts.ExcludeTags = ""
    opts.Search = ""
    opts.Text (:,1) string = string.empty(0, 1)
end

n = numel(subject);
if numel(tagSets) ~= n
    error('datasetFilter:BadSize', 'TAGSETS has %d entries for %d subjects.', numel(tagSets), n);
end
text = opts.Text;
if isempty(text) && n > 0
    text = subject;
elseif numel(text) ~= n
    error('datasetFilter:BadSize', 'Text has %d entries for %d subjects.', numel(text), n);
end

include = filterTerms(opts.Subjects);
exclude = filterTerms(opts.ExcludeSubjects);
words = reshape(split(strtrim(join(reshape(string(opts.Search), 1, []), " "))), 1, []);
words = lower(words(strlength(words) > 0));
picked = tagTerms(opts.Tags);
dropped = tagTerms(opts.ExcludeTags);

keep = true(n, 1);
if ~isempty(include)
    keep = keep & matchSubject(subject, include);
end
if ~isempty(exclude)
    keep = keep & ~matchSubject(subject, exclude);
end
keep = keep & reshape(TagSet.matches(tagSets, picked, opts.TagMode), [], 1);   % an empty PICKED passes all; a bad mode errors
if ~isempty(dropped)
    keep = keep & ~reshape(TagSet.matches(tagSets, dropped, "any"), [], 1);
end
low = lower(text);
for w = words
    keep = keep & contains(low, w);
end
active = ~(isempty(include) && isempty(exclude) && isempty(picked) && isempty(dropped) && isempty(words));
end


function terms = filterTerms(value)
%filterTerms  Comma-separated text or strings -> terms ("" and "(any)" are none).
terms = strtrim(split(join(reshape(string(value), 1, []), ","), ","));
terms = reshape(terms(terms ~= "" & terms ~= "(any)"), 1, []);
end


function selected = tagTerms(value)
%tagTerms  Tag filter text -> the tags in it, then the terms that are no valid tag as typed (they match nothing).
terms = filterTerms(value);
[tags, bad] = TagSet.fromText(terms, TagSet.EntryDelimiter);
selected = [reshape(tags, 1, []), reshape(bad, 1, [])];
end


function tf = matchSubject(subject, terms)
%matchSubject  Whether each subject (a column) matches any term, whole and ignoring case, with * and ? as wildcards.
tf = false(numel(subject), 1);
for t = terms
    pat = "^" + replace(replace(regexptranslate('escape', t), "\*", ".*"), "\?", ".") + "$";
    tf = tf | reshape(~cellfun(@isempty, regexpi(cellstr(subject), pat, 'once')), [], 1);
end
end
