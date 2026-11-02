function busy = inUse(obj, d)
%inUse  Why dataset D cannot be written now: another session works on it, else "".
%   BUSY = pipe.inUse(D) is "in use by another session (HOST, since T): ..."
%   when a live run or sort lock of another process holds D (RunLock), ""
%   when none does. The locks of this process - the run's own, a sort it
%   started - never count. The steps that write (sorting, signals, spikes,
%   export) skip such a dataset, and plan() lists it as "skip: in use by
%   another session".
%
%   See also RunLock, EphysPipeline.run.

arguments
    obj (1,1) EphysPipeline %#ok<INUSA>
    d (1,1) EphysDataset
end

busy = "";
[held, info] = RunLock.heldElsewhere(d);
if held
    busy = RunLock.describe(info);
end
end
