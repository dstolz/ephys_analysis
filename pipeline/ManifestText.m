classdef ManifestText
%ManifestText  Read a decoded <Name>_manifest.json and put its values in words.
%   What the manifest's readers share: ManifestViewerApp's Summary and
%   PipelineDiagram.manifest show a value the same way. None of it touches
%   the disk, and a field that is missing or of the wrong type gives the
%   default, so a hand-edited or older manifest still reads.
%
%     ManifestText.field(S, "a.b", DEFAULT)  field at a dotted path, else DEFAULT
%     ManifestText.text(V)                   a text field as a string ("" for null / non-text)
%     ManifestText.number(V)                 a number as a double (NaN for null / non-numeric)
%     ManifestText.value(V)                  any value as one line of text
%     ManifestText.reference(REF)            a record's common reference in words
%     ManifestText.localReference(GROUPS)    a record's local reference in words
%     ManifestText.sortReference(R)          the reference a sort saw, in words, and any warning
%
%   See also ManifestViewerApp, PipelineDiagram.manifest, EphysDataset.writeManifest.

    methods (Static)
        function v = field(s, path, default)
            %field  Field at a dotted path, or DEFAULT when any level is missing.
            v = default;
            for p = split(string(path), ".").'
                if ~isstruct(s) || ~isscalar(s) || ~isfield(s, p); return; end
                s = s.(p);
            end
            v = s;
        end

        function s = text(v)
            %text  A manifest string field as a string ("" for null / non-text).
            if ischar(v) || (isstring(v) && isscalar(v))
                s = string(v);
            elseif iscellstr(v) || isstring(v)
                s = strjoin(string(v), ", ");
            else
                s = "";
            end
        end

        function x = number(v)
            %number  A manifest number as a double (NaN for null / non-numeric).
            x = NaN;
            if (isnumeric(v) || islogical(v)) && isscalar(v)
                x = double(v);
            end
        end

        function s = value(v)
            %value  Any decoded value as one line: a list in brackets, a long array as its size.
            if ischar(v) || (isstring(v) && isscalar(v))
                s = string(v);
            elseif isempty(v)
                s = "null";
            elseif isstring(v)
                s = "[" + strjoin(v, ", ") + "]";
            elseif islogical(v) && isscalar(v)
                s = ternary(v, "true", "false");
            elseif isnumeric(v) && isscalar(v)
                s = string(num2str(double(v), 10));
            elseif (isnumeric(v) || islogical(v)) && numel(v) <= 24
                if isvector(v); v = reshape(v, 1, []); end   % jsondecode gives a list as a column
                s = string(mat2str(double(v), 6));
            elseif isnumeric(v) || islogical(v)
                s = sprintf('[%s %s]', strjoin(string(size(v)), 'x'), class(v));
            elseif iscell(v)
                parts = string(cellfun(@(x) char(ManifestText.value(x)), v(1:min(end, 12)), 'UniformOutput', false));
                s = "[" + strjoin(parts, ", ") + ternary(numel(v) > 12, ", ...", "") + "]";
            elseif isstruct(v)
                s = sprintf('{%d fields}', numel(fieldnames(v)));
            else
                s = "<" + class(v) + ">";
            end
        end

        function s = reference(ref)
            %reference  A processing record's common reference in words: the local
            %   reference subtracted first (localReference), the mode, the
            %   channels it was taken over, the weighted CAR's order and Q, and the
            %   derived signals it was subtracted from.
            mode = ManifestText.text(ManifestText.field(ref, 'mode', ""));
            ch = ManifestText.text(ManifestText.field(ref, 'channels', ""));
            switch mode
                case "none"
                    s = "none";
                case {"car" "cmr"}
                    s = upper(mode) + " over channels " + ch;
                case "wcar"
                    s = "weighted CAR over channels " + ch;
                    w = ManifestText.field(ref, 'wcar', []);
                    if isstruct(w) && isscalar(w)
                        s = s + sprintf(' (Order %s, Q %.4g µV²%s)', ...
                            string(num2str(ManifestText.number(ManifestText.field(w, 'Order', NaN)), 10)), ...
                            ManifestText.number(ManifestText.field(w, 'Q', NaN)), ...
                            ternary(isequal(ManifestText.field(w, 'QAuto', false), true), ", automatic", ""));
                    end
                otherwise
                    s = mode;
            end
            loc = ManifestText.localReference(ManifestText.field(ref, 'local', []));
            if loc ~= "" && mode == "none"
                s = loc;
            elseif loc ~= ""
                s = loc + ", then " + s;
            end
            sig = ManifestText.field(ref, 'signals', []);
            if (iscell(sig) || isstring(sig) || ischar(sig)) && ~isempty(sig) && (mode ~= "none" || loc ~= "")
                s = s + ", subtracted from " + strjoin(string(sig), ", ");
            end
        end

        function s = localReference(groups)
            %localReference  A record's local reference in words: "local reference: 17 from 1-16; 40 from 33-48"
            %   ("" for none). GROUPS as the manifest holds them
            %   (EphysDataset.localReferenceRecord: reference, channels as a
            %   compact list), a struct array or a cell array of structs.
            s = "";
            if isempty(groups); return; end
            if isstruct(groups); groups = num2cell(groups); end
            if ~iscell(groups); return; end
            parts = strings(1, 0);
            for k = 1:numel(groups)
                g = groups{k};
                if ~isstruct(g); continue; end
                r = ManifestText.field(g, 'reference', "");
                if isnumeric(r) && isscalar(r)
                    r = string(r);        % a channel number, as the manifest holds it
                else
                    r = ManifestText.text(r);
                end
                parts(end + 1) = r + " from " + ManifestText.text(ManifestText.field(g, 'channels', "")); %#ok<AGROW>
            end
            if ~isempty(parts)
                s = "local reference: " + strjoin(parts, "; ");
            end
        end

        function [s, level, check] = sortReference(r)
            %sortReference  The reference a sort saw: the .bin's, and the sorter's own on
            %   top of it (Kilosort4's do_CAR). Both is a warning, as is a .bin whose
            %   is unknown. LEVEL is "" or "warn", CHECK says why.
            br = ManifestText.text(ManifestText.field(r, 'bin_reference', ""));
            sorter = ManifestText.text(ManifestText.field(r, 'sorter', ""));
            level = ""; check = "";
            if br == ""
                s = "unknown in the .bin";
                level = "warn"; check = "the .bin had no readable sidecar";
            else
                s = upper(br) + " in the .bin";
            end
            if isequal(ManifestText.field(r, 'bin_local_reference', false), true)
                s = "local reference" + ternary(br == "none", "", " then " + upper(br)) + " in the .bin";
            end
            if isequal(ManifestText.field(r, 'own_reference', false), true)
                s = s + "; " + ternary(sorter == "kilosort4", "Kilosort4's do_CAR (median across channels)", ...
                    sorter + "'s own, if it has one");
                if ismember(br, ["car" "cmr" "wcar"])
                    level = "warn"; check = "referenced twice";
                end
            else
                s = s + "; none of the sorter's own";
            end
        end
    end
end


function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
