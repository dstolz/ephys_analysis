classdef test_PlatformSupport < matlab.unittest.TestCase
    %test_PlatformSupport  platformSupport's matrix and its one error; openInSystem's.
    %   The matrix has every feature once, with yes / untested / no per
    %   platform, and Here follows this machine's column. A feature that is
    %   "no" here raises platformSupport:Unsupported, or the caller's own
    %   identifier, naming what it uses and the alternative. On Windows no
    %   feature is "no", so that test is skipped there.
    %
    %   Usage:  runtests("test_PlatformSupport")

    methods (Test)
        function matrix(tc)
            T = platformSupport();
            tc.verifyEqual(string(T.Properties.VariableNames), ...
                ["Feature" "Description" "Uses" "Windows" "macOS" "Linux" "Alternative" "Here"]);
            tc.verifyEqual(numel(unique(T.Feature)), height(T), 'each feature once');
            tc.verifyTrue(all(ismember([T.Windows; T.macOS; T.Linux], ["yes" "untested" "no"])));
            tc.verifyTrue(all(T.Windows == "yes"), 'everything runs on Windows');
            if ispc; col = "Windows"; elseif ismac; col = "macOS"; else; col = "Linux"; end
            tc.verifyEqual(T.Here, T.(col) ~= "no");
            for k = 1:height(T)
                tc.verifyEqual(platformSupport(T.Feature(k)), T.Here(k));
            end
            tc.verifyError(@() platformSupport("teleport"), 'platformSupport:UnknownFeature');
        end

        function refusesHere(tc)
            T = platformSupport();
            no = T.Feature(~T.Here);
            tc.assumeNotEmpty(no, "every feature runs on this platform");
            tc.verifyError(@() platformSupport(no(1), Require=true), 'platformSupport:Unsupported');
            tc.verifyError(@() platformSupport(no(1), Require=true, ErrorId="mine:NotHere"), 'mine:NotHere');
            try
                platformSupport(no(1), Require=true);
            catch ME
                row = T.Feature == no(1);
                tc.verifyTrue(contains(ME.message, T.Uses(row)) && contains(ME.message, T.Alternative(row)), ...
                    'the message names what it uses and the alternative');
            end
        end

        function openMissing(tc)
            tc.verifyError(@() openInSystem(fullfile(tempdir, "no_such_folder_" + string(randi(1e9)))), ...
                'openInSystem:Missing');
        end
    end
end
