## Prompt for coding agent: MATLAB Remote Analysis System

**Objective**

Design and implement a lightweight remote analysis system that allows me to interactively analyze large neural electrophysiology datasets from my laptop using MATLAB, while keeping the underlying data and computationally intensive operations on a shared Windows 11 workstation.

I want to develop and run analysis scripts locally without having to download large preprocessed datasets to my laptop. Instead, my local MATLAB scripts should be able to submit analysis requests to the remote workstation and retrieve only the results I need, such as PSTHs, event-aligned averages, summary statistics, or other relatively small MATLAB arrays.

The system should be flexible enough to support exploratory analysis, where I frequently change parameters and rerun analyses.

### 1. Existing environment

Assume the following environment:

- **Local client:** My laptop, running MATLAB.
- **Remote worker:** A Windows 11 workstation with substantial RAM, processing power, and GPU resources.
- **Data storage:** Large raw and preprocessed neural datasets reside on the remote workstation or network-attached storage (NAS).
- **Communication:** Both machines can access an appropriate shared network location, subject to permissions and campus IT restrictions.
- **Existing workflow:** I already have a preprocessing pipeline that processes raw electrophysiology data. I want to build a separate system for flexible, downstream analysis of the resulting datasets.
- **Other users:** The remote workstation is shared with other users and processes. My analysis jobs must not monopolize its resources or interfere with existing workflows.

Do not assume that the remote workstation can accept arbitrary incoming network connections. Prefer an architecture that works with an existing shared folder if that is the simplest viable option.

Before implementing anything, inspect the existing project and identify relevant MATLAB versions, data formats, folder conventions, and existing analysis functions. Reuse existing code where appropriate rather than duplicating analysis logic.

### 2. Desired user experience

The most important requirement is that remote analysis should feel natural from within MATLAB on my laptop.

For example, I want to write a local script like this:

_note that the following code is illustrative and not a requirement to use these exact field names or output structures. we should make use of existing code and conventions in the ephys_analysis repository_

```matlab
% Specify the dataset and analysis parameters.
session = "Session_001";

params.event = "stimulus_onset";
params.window = [-0.5, 1.0];
params.binWidth = 0.010;
params.smoothing = 0.020;

% Request remote analysis and retrieve the result.
result = remotePSTH(session, params);

% Continue analyzing and plotting locally.
figure;
plot(result.time, result.meanPSTH);

xlabel('Time (s)');
ylabel('Firing rate (spikes/s)');
```

This is an illustrative API, not a requirement to use these exact field names or output structures. Adapt the interface to existing project conventions.

The critical behavior is:

1. I call a MATLAB function on my laptop.
2. The function packages the requested analysis and its parameters.
3. The request is submitted to the remote workstation.
4. The remote workstation locates the dataset and performs the analysis.
5. Only the requested results are transferred back.
6. MATLAB returns those results to my local workspace in a convenient structure.

I should not need to manually copy datasets, open a remote desktop session, or interact with a separate GUI to execute each analysis.

**The local MATLAB function should hide the communication details.** From the perspective of my analysis script, calling a remote function should be nearly as straightforward as calling an ordinary local function.

### 3. Architecture

Implement a simple client-worker architecture.

**A. Local MATLAB client**

Create a small set of MATLAB functions responsible for:

- Accepting analysis parameters and dataset identifiers.
- Generating a unique job ID.
- Serializing the request into a format the worker can interpret.
- Submitting the request to the shared job queue.
- Waiting for completion when requested.
- Retrieving and loading the results into MATLAB.
- Reporting progress, failures, and timeouts clearly.

The interface should support both synchronous and asynchronous execution if practical.

For example:

```matlab
% Synchronous: wait for the result.
result = remotePSTH(session, params);

% Asynchronous: submit the job and return a handle.
job = submitRemoteAnalysis(session, "PSTH", params);

% Check whether the job has finished.
status = getRemoteJobStatus(job);

% Retrieve the result when ready.
result = fetchRemoteResult(job);
```

These function names are illustrative. Choose a consistent API that fits the project.

**B. Remote worker**

Create a worker process that runs on the Windows 11 workstation.

The worker should:

- Monitor a designated request queue.
- Detect new jobs and claim them safely.
- Validate each request before execution.
- Resolve dataset identifiers to local or NAS paths.
- Invoke the appropriate MATLAB analysis function.
- Save results to a designated output location.
- Record job status, execution time, and any errors.
- Release resources and mark the job as complete or failed.

The worker should not require an interactive MATLAB session if unattended execution is permitted by the workstation's licensing and IT configuration.

Investigate whether MATLAB batch execution is appropriate for the installed MATLAB version and license. Do not assume that a particular licensing arrangement permits additional unattended MATLAB processes.

**C. Shared storage**

Use the shared network location for communication between the client and worker.

A possible layout is:

```text
RemoteAnalysis/
    requests/
    running/
    completed/
    results/
    logs/
```

Each job should have its own request file, status information, and result file.

Avoid collisions when multiple jobs are submitted simultaneously. The worker must not execute the same request twice because of repeated polling or an interrupted client connection.

Use an appropriate atomic file-creation or file-renaming strategy for claiming jobs. Do not assume that a file is completely written merely because it has appeared in the shared directory.

Keep temporary files and incomplete results separate from completed outputs.

### 4. Analysis parameters must remain flexible

This is a central requirement.

I am developing analysis methods, not simply running a fixed production pipeline. I may repeatedly change parameters such as:

- Event definitions and alignment times.
- Analysis windows.
- PSTH bin widths.
- Smoothing parameters.
- Unit selection.
- Trial selection and behavioral conditions.
- Correct versus incorrect trials.
- Preprocessing options.
- Filtering parameters.
- Analysis-specific settings.

The system must allow me to submit new parameter combinations without modifying the worker's source code or restarting the worker.

The request should specify the analysis type, dataset or session identifier, parameters, and any other necessary metadata.

The worker should dispatch the request to an appropriate analysis function.

Initially, implement only one analysis type: a PSTH calculation using an existing dataset and event definitions.

Design the architecture so that additional analysis functions can be added later without rewriting the communication infrastructure.

Do not build a large, general-purpose framework prematurely.

### 5. Result handling

The goal is to minimize network traffic.

The remote worker should return only the requested results, rather than transferring entire recordings or large intermediate datasets.

For example, a PSTH result might contain:

```matlab
result.time
result.meanPSTH
result.semPSTH
result.unitIDs
result.trialCount
result.params
```

Adapt these fields to the existing data structures and analysis conventions.

Where useful, return additional information such as per-trial responses, condition-specific averages, or confidence intervals. Do not calculate or transfer unnecessary outputs by default.

Save results in a format that MATLAB can load efficiently and reliably.

MAT-files are a reasonable starting point. Consider `-v7.3` when large arrays require it, but do not assume that every result needs this format.

The local client should receive a reference to the result file or enough information to retrieve it from the shared storage.

### 6. Caching and repeated analyses

Because I expect to explore many parameter combinations, consider adding a result cache.

If the same analysis has already been completed using the same dataset version, analysis implementation, and parameters, the system should be able to reuse the existing result instead of recalculating it.

However, caching must be correct.

A cached result must not be reused when relevant inputs have changed, including:

- Analysis parameters.
- Dataset versions or underlying data.
- Event definitions.
- Relevant analysis code or preprocessing versions.

Use a deterministic representation of the relevant inputs to identify equivalent jobs.

Caching is desirable, but it should not delay implementation of the basic working system. Implement it after the initial request-worker-result workflow works correctly.

### 7. Resource management and reliability

The workstation is shared, so resource management matters.

Implement reasonable safeguards:

- Limit the number of simultaneous jobs.
- Avoid starting multiple expensive MATLAB processes unnecessarily.
- Allow jobs to run at a configurable priority when supported.
- Provide a way to identify, cancel, or abandon jobs when practical.
- Handle worker restarts and interrupted client connections.
- Distinguish queued, running, completed, failed, and cancelled jobs.
- Provide useful error messages and logs.
- Prevent partially written results from being treated as complete.
- Avoid deleting or overwriting another user's files.

Do not assume that lowering process priority alone will adequately control memory use or GPU contention.

Make worker resource limits configurable. Do not implement aggressive scheduling or automatic resource allocation unless the existing environment supports it.

### 8. Security and institutional constraints

The system must respect campus IT policies.

- Use existing authorized network access.
- Do not expose a new network service or open firewall ports unless explicitly authorized.
- Do not embed credentials in scripts or configuration files.
- Restrict requests to approved datasets and analysis functions.
- Validate requests rather than executing arbitrary commands supplied by the client.
- Avoid changing workstation-wide settings.
- Do not interfere with other users' sessions or existing pipelines.

Keep configuration separate from application code so that network paths, MATLAB executable locations, and other environment-specific settings can be changed without editing the analysis functions.

### 9. Development strategy

Implement this incrementally.

**Phase 1: Minimal working prototype**

Create the smallest end-to-end implementation that:

1. Starts a worker on the Windows workstation.
2. Accepts a request from my laptop.
3. Locates one known preprocessed dataset.
4. Computes a PSTH for a specified event and parameter set.
5. Saves the result.
6. Allows the local MATLAB client to retrieve the result as a MATLAB structure.

Use a small test dataset or a limited number of units.

**Phase 2: Exploratory analysis workflow**

Add:

- Flexible parameter submission.
- Clear status reporting.
- Synchronous and asynchronous execution, if practical.
- Robust error handling.
- Unique job IDs.
- Basic logging.

**Phase 3: Efficiency and expansion**

Consider:

- Result caching.
- Additional analysis types.
- Improved job scheduling.
- Cancellation and recovery.
- Efficient retrieval of subsets of results.

Do not implement all three phases at once.

Get Phase 1 working and validated before expanding the system.

### 10. Testing and validation

Create tests that verify both the remote infrastructure and the scientific calculations.

At minimum:

1. Confirm that the client can submit a request and retrieve a result.
2. Verify that the worker processes a request exactly once.
3. Verify that a failed job produces a useful error.
4. Verify that changing a parameter produces the expected change in the analysis.
5. Compare the remote PSTH with the existing local analysis function using identical inputs.
6. Confirm that the remote worker does not transfer the underlying neural recordings to the laptop.
7. Test multiple submitted jobs and confirm that their results remain separate.
8. Verify that interrupted jobs do not produce results incorrectly marked as complete.

The remote and local calculations should agree within an appropriate numerical tolerance.

Do not modify the established scientific analysis merely to make the test pass. If existing code has ambiguous assumptions about event times, units, bin edges, smoothing, or trial inclusion, identify those assumptions explicitly.

### 11. How I want you to work as my coding agent

Before writing code:

1. Inspect the existing project structure and relevant analysis functions.
2. Identify the current data formats, MATLAB version, and available shared paths.
3. Propose the smallest practical architecture for the first working prototype.
4. Identify any assumptions that need confirmation.

Then implement the first working version.

Prefer a few small, understandable MATLAB functions over a large framework. Keep the client API stable, separate the communication layer from the scientific analysis, and document the configuration and setup steps.

Do not rewrite unrelated parts of the project.

Do not invent dataset paths, event definitions, or analysis conventions. If required information is unavailable, ask me or use clearly identified placeholders.

When finished, provide:

- A description of the architecture.
- The files created or modified.
- Setup instructions for the workstation and laptop.
- A minimal example of submitting a PSTH request.
- Tests and their results.
- Known limitations and any remaining configuration steps.

**The definition of success is simple:** I should be able to sit at my laptop, experiment with MATLAB analysis scripts, change parameters freely, and obtain results from large neural datasets stored on the campus workstation without manually transferring the underlying data.
