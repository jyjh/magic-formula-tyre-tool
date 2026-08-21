classdef ParserDiscovery < matlab.unittest.TestCase
    methods (Test)
        function onlyTydexParserSubclassesAreListed(testCase)
            [names,handles] = helpers.getParsers();

            testCase.verifyTrue(ismember('FSAETTC_SI_ISO_Mat',names));
            testCase.verifyFalse(ismember('FSAETTCSummary',names));
            for i = 1:numel(handles)
                testCase.verifyInstanceOf(handles{i}(),'tydex.Parser');
            end
        end
    end
end
