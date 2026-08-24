classdef TyreFitterPanel < matlab.ui.componentcontainer.ComponentContainer
    %TyreFitterPanel Provides GUI to configure and run Fitter.
    
    events (HasCallbackProperty, NotifyAccess = protected)
        FitterStartRequested
        FitterFittingModesChanged
        FitterSolverSettingsChanged
    end

    properties (Access = private, Transient, NonCopyable)
        Grid                        matlab.ui.container.GridLayout
        MainGrid                    matlab.ui.container.GridLayout
        Panel                       matlab.ui.container.Panel
        FittingModesPanel           ui.TyreFitterFittingModesPanel
        SolverSettingsPanel         ui.TyreFitterSolverSettingsPanel
        RunStateButton              matlab.ui.control.Button
    end

    methods (Access = private)
        function onFittingModesChanged(obj, ~, event)
            modes = event.FitModes;
            evntdata = events.FittingModesChangedEventData(modes);
            notify(obj, 'FitterFittingModesChanged', evntdata)
        end
        function onSolverSettingsChanged(obj, ~, event)
            settings = event.Settings;
            evntdata = events.FitterSettingsChangedEventData(settings);
            notify(obj, 'FitterSolverSettingsChanged', evntdata)
        end
        function onRunStateButtonValueChanged(obj, ~, ~)
            notify(obj, 'FitterStartRequested')
        end
    end
    
    methods (Access = protected)
        function setup(obj)
            obj.Position = [0 0 400 400];
            obj.MainGrid = uigridlayout(obj, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', zeros(1,4));
            obj.Panel = uipanel(obj.MainGrid);
            obj.Grid = uigridlayout(obj.Panel, ...
                'RowHeight', {'fit', 'fit', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', zeros(1,4), ...
                'ColumnSpacing', settings.LayoutSettings.DefaultColumnSpacing);
            obj.FittingModesPanel = ui.TyreFitterFittingModesPanel(obj.Grid, ...
                'SelectionChangedFcn', @obj.onFittingModesChanged);
            obj.SolverSettingsPanel = ui.TyreFitterSolverSettingsPanel(obj.Grid, ...
                'SettingsChangedFcn', @obj.onSolverSettingsChanged);
            p = uipanel(obj.Grid, ...
                'Title', ' ', ...
                'FontWeight', settings.TextSettings.FontWeightPanel, ...
                'BorderType', 'none');
            g = uigridlayout(p, ...
                'RowHeight', {settings.LayoutSettings.DefaultButtonHeight}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', settings.LayoutSettings.DefaultPadding);
            obj.RunStateButton = uibutton(g, ...
                'Text', 'Run Fitter', ...
                'Icon', 'play-solid.svg', ...
                'ButtonPushedFcn', @obj.onRunStateButtonValueChanged);
        end
        function update(obj)
        end
    end
end
