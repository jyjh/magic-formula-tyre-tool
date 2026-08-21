classdef ThemeSettings < matlab.unittest.TestCase
    %Unit tests for settings.ThemeSettings.
    %The theme centralizes color/font literals that were previously
    %hard-coded across UI components. These tests guard the expected
    %property set so a rename or removal is caught.
    methods (Test)
        function exposesExpectedProperties(testCase)
            s = settings.ThemeSettings();
            props = properties(s);
            expected = {'FigureBackground', 'SearchMatchHighlight', ...
                'SearchMatchSelected', 'FittedParameterFontColor', ...
                'PlotFontName'};
            for i = 1:numel(expected)
                testCase.assertNotEmpty(s.(expected{i}), sprintf(...
                    'Theme property %s must not be empty.', expected{i}));
                testCase.assertTrue(ismember(expected{i}, props), sprintf(...
                    'Theme must expose property %s.', expected{i}));
            end
        end
        function figureBackgroundIsRgbTriplet(testCase)
            s = settings.ThemeSettings();
            bg = s.FigureBackground;
            testCase.verifySize(bg, [1 3]);
            testCase.verifyTrue(all(bg >= 0 & bg <= 1), ...
                'FigureBackground must be an RGB triplet in [0,1].');
        end
        function colorLiteralsAreHexStrings(testCase)
            s = settings.ThemeSettings();
            hexProps = {'SearchMatchHighlight', 'SearchMatchSelected', ...
                'FittedParameterFontColor'};
            for i = 1:numel(hexProps)
                value = s.(hexProps{i});
                testCase.assertInstanceOf(value, 'char');
                testCase.verifyTrue(...
                    matches(value, asManyOfPattern('#' + alphanumericsPattern)), ...
                    sprintf('Theme color %s must be a hex string like ''#RRGGBB''.', ...
                    hexProps{i}));
            end
        end
    end
end
