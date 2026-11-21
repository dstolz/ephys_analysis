function restore = quietHeaderNotes()
%quietHeaderNotes  Stop the reader's warnings about switched channels and clock jumps while the caller reads headers.
%   RESTORE = quietHeaderNotes() turns off IntanReader:refreshMetadata:ChannelsDropped
%   and IntanReader:TimestampGap and returns an onCleanup that puts them back
%   as they were when it goes out of scope (keep it in a variable). The app
%   shows the same notes per dataset instead (syncDatasetWarnings), so a scan
%   of dozens of recordings does not fill the command window with them.
%
%   See also EphysDataset.metadataNotes, syncDatasetWarnings.
quiet = [warning('off', 'IntanReader:refreshMetadata:ChannelsDropped'), ...
         warning('off', 'IntanReader:TimestampGap')];
restore = onCleanup(@() warning(quiet));
end
