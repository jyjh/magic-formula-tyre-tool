classdef C6Gating < matlab.unittest.TestCase
    %Unit tests for helpers.shouldIgnoreC6Buckets.
    %The bucket filter is masked by workbook availability; this truth
    %table guards that rule so the interactive and last-session import
    %paths stay in agreement.
    methods (Test)
        function flagFalseAndNoWorkbook(testCase)
            testCase.verifyFalse(...
                helpers.shouldIgnoreC6Buckets(false, char.empty));
        end
        function flagTrueButNoWorkbook(testCase)
            %Flag alone is insufficient: no workbook means no bucket
            %filtering can apply, so the rule resolves to false.
            testCase.verifyFalse(...
                helpers.shouldIgnoreC6Buckets(true, char.empty));
        end
        function flagFalseButWorkbookPresent(testCase)
            testCase.verifyFalse(...
                helpers.shouldIgnoreC6Buckets(false, 'summary.xlsx'));
        end
        function flagTrueAndWorkbookPresent(testCase)
            testCase.verifyTrue(...
                helpers.shouldIgnoreC6Buckets(true, 'summary.xlsx'));
        end
        function requiresLogicalFlag(testCase)
            %A flag that cannot be used as a scalar logical must be
            %rejected by the arguments block. (Scalar numerics and chars
            %are valid logical conversions, so a non-scalar is used here.)
            testCase.assertError(...
                @() helpers.shouldIgnoreC6Buckets([1 1], 'summary.xlsx'), ...
                'MATLAB:validation:IncompatibleSize');
        end
    end
end
