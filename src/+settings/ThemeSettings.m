classdef ThemeSettings < settings.AbstractSettings
    %THEMESETTINGS Centralized app theme: figure, table and plot colors.
    %All properties are Constant so the save/load recursion skips them and
    %they cannot drift into the persistent settings tree. Color literals
    %that were previously hard-coded across UI components live here now.
    properties (Constant, AbortSet)
        FigureBackground double = [1 1 1]
        SearchMatchHighlight char = '#FFFFE0'
        SearchMatchSelected char = '#6495ED'
        FittedParameterFontColor char = '#006400'
        PlotFontName char = 'FixedWidth'
    end
end
