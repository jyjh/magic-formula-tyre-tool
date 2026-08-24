classdef ThemeSettings
    %THEMESETTINGS Centralized app theme: figure, table and plot colors.
    %Plain constants class: nothing here persists, so it deliberately
    %takes no part in the AbstractSettings save/load recursion. Color
    %literals that were previously hard-coded across UI components live
    %here now.
    properties (Constant)
        FigureBackground double = [1 1 1]
        SearchMatchHighlight char = '#FFFFE0'
        SearchMatchSelected char = '#6495ED'
        FittedParameterFontColor char = '#006400'
        PlotFontName char = 'FixedWidth'
    end
end
