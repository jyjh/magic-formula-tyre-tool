classdef ButtonCollapse < matlab.unittest.TestCase
    %Unit tests for helpers.collapseButtonTextOnResize.
    %Guards the width threshold at which button text is collapsed to
    %icon-only, and that text is restored (vectorized, not the old
    %slow per-button loop) when space is available again.
    properties
        TestFigure matlab.ui.Figure
        TestGrid   matlab.ui.container.GridLayout
        Texts      cell
    end
    methods (TestClassSetup)
        function createGrid(testCase)
            f = uifigure('Position', [0 0 1000 100]);
            s = settings.LayoutSettings();
            w = s.DefaultButtonWidthTextIcon;
            iconW = s.DefaultButtonWidthOnlyIcon;
            g = uigridlayout(f, ...
                'RowHeight', {s.DefaultButtonHeight}, ...
                'ColumnWidth', {w, w, w, '1x'}, ...
                'ColumnSpacing', s.DefaultColumnSpacing, ...
                'Padding', zeros(1,4));
            testCase.TestFigure = f;
            testCase.TestGrid = g;
            texts = {'Alpha', 'Beta', 'Gamma'};
            for i = 1:numel(texts)
                uibutton(g, 'Text', texts{i});
            end
            testCase.Texts = texts;
        end
    end
    methods (TestClassTeardown)
        function deleteGrid(testCase)
            delete(testCase.TestFigure)
        end
    end
    methods (Test)
        function blanksTextWhenTooNarrow(testCase)
            g = testCase.TestGrid;
            w = settings.LayoutSettings().DefaultButtonWidthTextIcon;
            iconW = settings.LayoutSettings().DefaultButtonWidthOnlyIcon;
            %A width far below the with-text minimum.
            helpers.collapseButtonTextOnResize(50, g, ...
                {w, w, w, '1x'}, {iconW, iconW, iconW, '1x'}, ...
                testCase.Texts);
            buttons = g.Children;
            for i = 1:numel(buttons)
                testCase.verifyEmpty(buttons(i).Text, ...
                    'Button text must be blanked when too narrow.');
            end
        end
        function restoresTextWhenWideEnough(testCase)
            g = testCase.TestGrid;
            w = settings.LayoutSettings().DefaultButtonWidthTextIcon;
            iconW = settings.LayoutSettings().DefaultButtonWidthOnlyIcon;
            %First collapse, then restore with a generous width.
            helpers.collapseButtonTextOnResize(50, g, ...
                {w, w, w, '1x'}, {iconW, iconW, iconW, '1x'}, ...
                testCase.Texts);
            helpers.collapseButtonTextOnResize(2000, g, ...
                {w, w, w, '1x'}, {iconW, iconW, iconW, '1x'}, ...
                testCase.Texts);
            buttons = g.Children;
            for i = 1:numel(buttons)
                testCase.assertEqual(buttons(i).Text, ...
                    testCase.Texts{i}, ...
                    'Button text must be restored when wide enough.');
            end
        end
    end
end
