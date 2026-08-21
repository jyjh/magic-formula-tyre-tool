classdef TyrePlotCurvesPanel < matlab.ui.componentcontainer.ComponentContainer
    %TYREPLOTCURVESPANEL Plot X-Var sweeps with corresponding Y-Var.
    
    properties
        Model MagicFormulaTyre = MagicFormulaTyre.empty
        Measurements tydex.Measurement = tydex.Measurement.empty
    end
    properties (Access = private)
        MeasurementsPlottable tydex.Measurement = tydex.Measurement.empty
        SteadyStateNamesAll = {
            'LONGSLIP'
            'SLIPANGL'
            'INCLANGL'
            'INFLPRES'
            'FZW'}
        LegendLabels = {};
        Settings settings.AppSettings
        ViewSettingsChangedListener event.listener
    end
    properties (Access = private, Transient, NonCopyable)
        MainGrid                    matlab.ui.container.GridLayout
        Axes                        matlab.ui.control.UIAxes
        SidePanel                   matlab.ui.container.Panel
        
        SidePanelGrid               matlab.ui.container.GridLayout
        PlotSettingsPanel           matlab.ui.container.Panel
        SteadyStateSettingsPanel    matlab.ui.container.Panel
        
        PlotSettingsPanelGrid       matlab.ui.container.GridLayout
        AutoRefreshStateButton      matlab.ui.control.StateButton
        HoldOnSettingStateButton    matlab.ui.control.StateButton
        DataShowSettingStateButton  matlab.ui.control.StateButton
        ModelShowSettingStateButton matlab.ui.control.StateButton
        ShowLegendStateButton       matlab.ui.control.StateButton
        XAxisSettingDropDown        matlab.ui.control.DropDown
        YAxisSettingDropDown        matlab.ui.control.DropDown
        XAxisRangeSelector          ui.NumericRangeSelector
        
        SteadyStateSettingsPanelGrid    matlab.ui.container.GridLayout
        SteadyStateSettingLabels        matlab.ui.control.Label
        SteadyStateSettingDropDowns     matlab.ui.control.DropDown
    end
    events (NotifyAccess = public)
        TyreModelChanged
        TyreDataChanged
    end
    methods (Access = private)
        function onModelChanged(obj, ~, event)
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            obj.Model = event.Model;
            if ~isempty(obj.Model) || s.AutoRefresh
                updatePlot(obj)
            end
        end
        function onDataChanged(obj, ~, event)
            measurements = event.Measurements;
            obj.Measurements = measurements;
        end
        function onSettingsChanged(obj, source, event)
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            tag = source.Tag;
            switch tag
                case {'AutoRefresh', 'DataShow', 'ModelShow'}
                    enable = event.Value;
                    s.(tag) = enable;
                case 'HoldOn'
                    enable = event.Value;
                    s.(tag) = enable;
                    return
                case {'XAxis', 'YAxis'}
                    axis = event.Value;
                    s.(tag) = axis;
                case 'LegendOn'
                    enable = event.Value;
                    s.(tag) = enable;
                    if enable
                        labels = obj.LegendLabels;
                        if ~isempty(labels)
                            legend(obj.Axes, labels, ...
                                'Location', 'southeast', ...
                                'Orientation', 'Horizontal', ...
                                'FontName', obj.Settings.Theme.PlotFontName, ...
                                'NumColumns', 3)
                        end
                    else
                        legend(obj.Axes, 'off')
                    end
                    return
            end
            updateDropDowns(obj)
            [names, values] = getSteadyStateUserSelection(obj);
            s.SteadyStateNamesSelected = names;
            s.SteadyStateValuesSelected = values;
            updatePlot(obj)
        end
    end
    methods(Access = protected, Static)
        function units = getUnitsFromNames(names)
            if ischar(names)
                names = {names};
            end
            
            units = cell(1,numel(names));
            for i = 1:numel(names)
                switch names{i}
                    case 'LONGSLIP'
                        units{i} = '1';
                    case {'SLIPANGL', 'INCLANGL'}
                        units{i} = 'deg';
                    case 'INFLPRES'
                        units{i} = 'bar';
                    case {'FZW', 'FYW', 'FX'}
                        units{i} = 'N';
                    case {'MZW', 'MXW', 'MYW'}
                        units{i} = 'Nm';
                end
            end
        end
    end
    methods(Access = private)
        function label = getLegendLabelFromNameValuePairs(obj, names, values)
            isRad = contains(names, {'INCLANGL', 'SLIPANGL'});
            isPascal = contains(names, 'INFLPRES');
            values(isRad) = cellfun(@rad2deg, values(isRad), ...
                'UniformOutput', false);
            values(isPascal) = cellfun(@helpers.pascal2bar, ...
                values(isPascal), 'UniformOutput', false);
            units = obj.getUnitsFromNames(names);
            values = cellfun(@(x)round(x,2), values, 'UniformOutput', false);
            valuesStr = cellfun(@num2str, values, 'UniformOutput', false);
            labelData = [names; values; units];
            lenLabel = max(cellfun(@numel, names));
            lenValue = max(cellfun(@numel, valuesStr)) + 3; % 3 = '.' + decimals
            label = sprintf(['\t\t%-' num2str(lenLabel) 's = %' num2str(lenValue) '.2f [%s]\n'], labelData{:});
        end
        function [names, values] = getSteadyStateUserSelection(obj)
            xAxisSetting = obj.XAxisSettingDropDown.Value;
            steadyStateNames = obj.XAxisSettingDropDown.Items;
            steadyStateValues = {obj.SteadyStateSettingDropDowns.Value};
            excludeIdx = strcmp(steadyStateNames, xAxisSetting);
            steadyStateNames(excludeIdx) = [];
            steadyStateValues(excludeIdx) = [];
            
            ischarIdx = cellfun(@ischar, steadyStateValues);
            steadyStateValues(ischarIdx) = cellfun(@str2double, ...
                steadyStateValues(ischarIdx), 'UniformOutput', false);
            isnanIdx = cellfun(@isnan, steadyStateValues);
            steadyStateValues(isnanIdx) = {0};
            isBarByUser = and(ischarIdx, ...
                contains(steadyStateNames, {'INFLPRES'}));
            isDegByUser = and(ischarIdx, ...
                contains(steadyStateNames, {'SLIPANGL', 'INCLANGL'}));
            steadyStateValues(isDegByUser) = cellfun(@deg2rad, ...
                steadyStateValues(isDegByUser), 'UniformOutput', false);
            steadyStateValues(isBarByUser) = cellfun(@helpers.bar2pascal, ...
                steadyStateValues(isBarByUser), 'UniformOutput', false);
            
            names = steadyStateNames;
            values = steadyStateValues;
        end
        function findSteadyStateValues(obj)
            % FINDSTEADYSTATEVALUES extracts all steady state values from
            % the loaded measurements. For example that in the testing data
            % three inclination angles were tested: 0, 2 and 4 degrees.
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;

            measurements = obj.Measurements;

            xAxis = obj.XAxisSettingDropDown.Value;
            yAxis = obj.YAxisSettingDropDown.Value;

            isPlottable = false(numel(measurements),1);
            for i = 1:numel(measurements)
                measurement = measurements(i);
                constantNames = {measurement.Constant.Name};
                isPlottable(i) = ~any(contains(constantNames, xAxis));
            end
            measurementsPlottable = measurements(isPlottable);
            obj.MeasurementsPlottable = measurementsPlottable;
            
            steadyStateNamesAll = obj.SteadyStateNamesAll;
            steadyStateValues = cell(1, numel(steadyStateNamesAll));
            steadyStateValues(:) = {{}};
            
            for i = 1:numel(measurementsPlottable)
                measurement = measurementsPlottable(i);
                
                constantNames = {measurement.Constant.Name};
                constantValues = [measurement.Constant.Value];
                excludeIdx = contains(constantNames, {'FNOMIN', 'NOMPRES'});
                constantNames(excludeIdx) = [];
                constantValues(excludeIdx) = [];  % keep in sync with constantNames
                
                for j = 1:numel(constantNames)
                    idx = find(strcmp(steadyStateNamesAll, constantNames{j}), 1);
                    % Unrecognized (e.g. custom) constants are not part of the
                    % five-name steady-state set; skip them rather than fail.
                    if isempty(idx)
                        continue
                    end
                    steadyStateValues{idx}(end+1,1) = {constantValues(j)};
                end
            end
            
            vars = obj.SteadyStateNamesAll;
            isFZ = strcmpi(vars, 'FZW');
            sortMethod = cell(numel(vars),1);
            sortMethod(:) = {'ascend'};
            sortMethod(isFZ) = {'descend'};
            for i = 1:size(steadyStateValues,2)
                vals = steadyStateValues{:,i};
                valsUnique = unique([vals{:}]');
                valsUniqueSorted = sort(valsUnique, sortMethod{i});
                valsUniqueSorted = num2cell(valsUniqueSorted);
                steadyStateValues{:,i} = valsUniqueSorted;
            end
            
            s.SteadyStateValues = steadyStateValues;
        end
        function measurements = getMeasurementAtSelectedSteadyStates(obj)
            measurements = obj.Measurements;
            if isempty(measurements)
                return
            end
            
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            steadyStateNames = s.SteadyStateNamesSelected;
            steadyStateValues = s.SteadyStateValuesSelected;
            
            indices = false(size(measurements));
            for i = 1:numel(measurements)
                measurement = measurements(i);
                
                constantNames = {measurement.Constant.Name};
                excludeIdx = contains(constantNames, {'FNOMIN', 'NOMPRES'});
                constantNames(excludeIdx) = [];
                areSteadyState = contains(constantNames, steadyStateNames);
                
                if ~all(areSteadyState)
                    continue
                end
                
                numVars = numel(steadyStateNames);
                j = 1;
                while j <= numVars
                    var = steadyStateNames{j};
                    val = steadyStateValues{j};
                    isValid = measurement.(var) == val;
                    if ~isValid
                        break
                    end
                    j = j+1;
                end
                indices(i) = isValid;
            end
            
            measurements = measurements(indices);
        end
        function onXAxisRangeChanged(obj, ~, event)
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            xAxisLabel = obj.XAxisSettingDropDown.Value;
            %Range settings follow the naming scheme XAxisRange<NAME>.
            if ~any(strcmp(xAxisLabel, obj.SteadyStateNamesAll))
                return
            end
            s.(['XAxisRange' xAxisLabel]) = event.Range;
            updatePlot(obj)
        end
    end
    methods (Access = protected)
        function updatePlot(obj)
            ax = obj.Axes;
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            holdOn = s.HoldOn;
            if ~holdOn
                cla(ax)
            end
            
            model = obj.Model;
            measurements = obj.MeasurementsPlottable;
            
            showModel = obj.ModelShowSettingStateButton.Value;
            showData = obj.DataShowSettingStateButton.Value;
            
            plotModel = ~isempty(model) && showModel;
            plotData = ~isempty(measurements) && showData;
            
            xVar = obj.XAxisSettingDropDown.Value;
            yVar = obj.YAxisSettingDropDown.Value;
            
            hData = gobjects().empty(1,0);
            hModel = gobjects().empty(1,0);
            
            vars = s.SteadyStateNamesSelected;
            vals = s.SteadyStateValuesSelected;
            
            if plotModel
                if ~any(strcmp(xVar, obj.SteadyStateNamesAll))
                    warning('Invalid x-axis variable!')
                    cla(ax)
                    return
                end
                %Model inputs are SI (rad, Pa); ranges and the x-axis are
                %in user units (deg, bar), so the swept variable converts.
                range = s.(['XAxisRange' xVar]);
                xVal = linspace(range(1), range(2));
                sweepSI = xVal;
                if any(strcmp(xVar, {'SLIPANGL', 'INCLANGL'}))
                    sweepSI = deg2rad(sweepSI);
                elseif strcmp(xVar, 'INFLPRES')
                    sweepSI = helpers.bar2pascal(sweepSI);
                end
                inputs = struct( ...
                    'LONGSLIP', vals{strcmp(vars, 'LONGSLIP')}, ...
                    'SLIPANGL', vals{strcmp(vars, 'SLIPANGL')}, ...
                    'INCLANGL', vals{strcmp(vars, 'INCLANGL')}, ...
                    'INFLPRES', vals{strcmp(vars, 'INFLPRES')}, ...
                    'FZW', vals{strcmp(vars, 'FZW')});
                inputs.(xVar) = sweepSI;

                %Outputs of magicformula are ordered [FX, FY, MZ, MY, MX];
                %note this differs from the Y-Axis dropdown item order.
                yOutputNames = {'FX', 'FYW', 'MZW', 'MYW', 'MXW'};
                k = find(strcmp(yOutputNames, yVar));
                if isempty(k)
                    warning('Invalid y-axis variable!')
                    cla(ax)
                    return
                end
                %Request exactly k outputs: magicformula only evaluates
                %the outputs that are requested (e.g. Mz may be undefined
                %for degenerate parameters while Fx is fine).
                outs = cell(1, k);
                [outs{:}] = magicformula(obj.Model, ...
                    inputs.LONGSLIP, inputs.SLIPANGL, inputs.FZW, ...
                    inputs.INFLPRES, inputs.INCLANGL);
                yVal = outs{k};

                hModel = plot(ax, xVal, yVal, 'LineWidth', 2);
            end

            if plotData
                measurements = getMeasurementAtSelectedSteadyStates(obj);
                if isempty(measurements)
                    fig = ancestor(obj, 'figure');
                    message = 'No data available for steady-state settings.';
                    title = 'Tyre Analysis';
                    uialert(fig, message, title)
                end

                if ~any(strcmp(xVar, obj.SteadyStateNamesAll))
                    warning('Invalid x-axis variable!')
                    cla(ax)
                    return
                end
                xVal = vertcat(measurements.(xVar));
                if any(strcmp(xVar, {'SLIPANGL', 'INCLANGL'}))
                    xVal = rad2deg(xVal);
                elseif strcmp(xVar, 'INFLPRES')
                    xVal = helpers.pascal2bar(xVal);
                end

                if ~ismember(yVar, obj.YAxisSettingDropDown.Items)
                    warning('Invalid y-axis variable!')
                    cla(ax)
                    return
                end
                yVal = vertcat(measurements.(yVar));

                if ~isempty(yVal)
                    hData = plot(ax, xVal, yVal, ...
                    'Marker', '.', ...
                    'LineStyle', 'none');
                end

                if plotModel
                    color = hModel.Color;
                    set(hData, 'Color', color);
                end
            end
            
            xUnit = char(obj.getUnitsFromNames(xVar));
            yUnit = char(obj.getUnitsFromNames(yVar));
            
            xlabel(ax, sprintf('%s / %s', xVar, xUnit))
            ylabel(ax, sprintf('%s / %s', yVar, yUnit))
            
            if ~isempty(hModel) && ~isempty(hData)
                labels = {'Model:', 'Data:'};
            elseif ~isempty(hModel)
                labels = {'Model:'};
            elseif ~isempty(hData)
                labels = {'Data:'};
            else
                labels = {};
            end
            
            if isempty(labels)
                legend(ax, 'off');
                obj.LegendLabels = {};
            else
                labelVals = getLegendLabelFromNameValuePairs(obj, ...
                    vars, vals);
                for i = 1:numel(labels)
                    labels{i} = sprintf('%s\n%s', labels{i}, labelVals);
                end
                if holdOn
                    labels = [obj.LegendLabels labels];
                end
                if ~obj.ShowLegendStateButton.Value
                    legend(ax, 'off');
                else
                    legend(labels, ...
                        'Location', 'southeast', ...
                        'Orientation', 'Horizontal', ...
                        'FontName', obj.Settings.Theme.PlotFontName, ...
                        'NumColumns', 3)
                end
                obj.LegendLabels = labels;
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % fixes a MATLAB issue with the axes toolbar disappearing.
            % see: mathworks.com/matlabcentral/answers/830253
            ax.Toolbar.HandleVisibility = 'off';
            ax.Toolbar.HandleVisibility = 'on';
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function updateDropDowns(obj)
            measurements = obj.Measurements;
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            if isempty(measurements)
                itemsSteadyState = s.SteadyStateValues;
                if any(cellfun(@isempty, itemsSteadyState))
                    itemsSteadyState = ...
                        settings.TyrePlotCurvesPanelViewSettings.DefaultSteadyStateValues;
                end
            else
                findSteadyStateValues(obj)
                itemsSteadyState = s.SteadyStateValues;
            end
            
            names = obj.SteadyStateNamesAll;
            for i = 1:size(itemsSteadyState, 2)
                dd = obj.SteadyStateSettingDropDowns(i);
                items = itemsSteadyState{i};
                if iscell(items)
                    items = cell2mat(items);
                end
                name = names{i};
                if contains(name, {'INCLANGL', 'SLIPANGL'})
                    items = rad2deg(items);
                end
                if contains(name, 'INFLPRES')
                    items = helpers.pascal2bar(items);
                end
                
                itemsStr = num2str(items);
                itemsStr = cellstr(itemsStr);
                itemsStr = erase(itemsStr, ' ');
                itemsStr(isempty(itemsStr)) = '';
                dd.Items = itemsStr;
                dd.ItemsData = itemsSteadyState{i};
            end
            
            %Whatever variable is set for X-Axis, cannot be steady-state:
            xAxisSetting = obj.XAxisSettingDropDown.Value;
            I = strcmp(xAxisSetting, obj.SteadyStateNamesAll);
            enable = matlab.lang.OnOffSwitchState(~I);
            enable = num2cell(enable);
            [obj.SteadyStateSettingDropDowns(:).Enable] = deal(enable{:});
        end
        function updateXAxisRangeSelector(obj)
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            xAxisLabel = obj.XAxisSettingDropDown.Value;
            limitsMap = struct( ...
                'LONGSLIP', [-1 1], ...
                'SLIPANGL', [-90 90], ...
                'INCLANGL', [-90 90], ...
                'INFLPRES', [0 10], ...
                'FZW', [0 1E5]);
            if ~isfield(limitsMap, xAxisLabel)
                return
            end
            obj.XAxisRangeSelector.RangeLimits = limitsMap.(xAxisLabel);
            obj.XAxisRangeSelector.Range = s.(['XAxisRange' xAxisLabel]);
            obj.XAxisRangeSelector.Unit = ...
                char(obj.getUnitsFromNames(xAxisLabel));
        end
        function updatePlotSettings(obj)
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            if isempty(obj.Model)
                set(obj.ModelShowSettingStateButton, 'Enable', 'off')
            else
                set(obj.ModelShowSettingStateButton, 'Enable', 'on')
            end
            
            if isempty(obj.Measurements)
                set(obj.DataShowSettingStateButton, 'Enable', 'off')
            else
                set(obj.DataShowSettingStateButton, 'Enable', 'on')
            end
            
            set(obj.AutoRefreshStateButton, 'Value', s.AutoRefresh)
        end
    end
    methods(Access = protected)
        function setupPlotSettingsPanel(obj)
            s = obj.Settings.Layout;
            w = s.DefaultButtonWidthTextIcon;
            grid = uigridlayout(obj.PlotSettingsPanel, ...
                'RowHeight', repmat({'fit'}, 9, 1), ...
                'ColumnWidth', {w, 'fit'}, ...
                'ColumnSpacing', s.DefaultColumnSpacing, ...
                'Padding', s.DefaultPadding, ...
                'Scrollable', false);
            
            s = obj.Settings.View.TyreAnalysisPanel.TyrePlotCurvesPanel;
            obj.PlotSettingsPanelGrid = grid;

            obj.AutoRefreshStateButton = uibutton(grid, 'state', ...
                'Text', 'Auto', ...
                'Value', s.AutoRefresh, ...
                'Tag', 'AutoRefresh', ...
                'Tooltip', 'Plot will update on new model changes.', ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(grid, 'Text', 'Auto-Refresh');

            obj.ShowLegendStateButton = uibutton(grid, 'state', ...
                'Text', 'On', ...
                'Value', s.LegendOn, ...
                'Tag', 'LegendOn', ...
                'Tooltip', 'Show/hide the plot legend.', ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(grid, 'Text', 'Show Legend');

            obj.HoldOnSettingStateButton = uibutton(grid, 'state', ...
                'Value', s.HoldOn, ...
                'Text', 'On', ...
                'Tooltip', ['Keep existing curves on the axes when the ' ...
                    'plot refreshes, so successive configurations ' ...
                    'overlay for comparison.'], ...
                'ValueChangedFcn', @obj.onSettingsChanged, ...
                'Tag', 'HoldOn');
            uilabel(grid, 'Text', 'Hold');

            obj.DataShowSettingStateButton = uibutton(grid, 'state', ...
                'Text', 'Show', ...
                'Value', s.DataShow, ...
                'Tooltip', 'Plot imported measurement points.', ...
                'ValueChangedFcn', @obj.onSettingsChanged, ...
                'Tag', 'DataShow');
            uilabel(grid, 'Text', 'Measurement Data');

            obj.ModelShowSettingStateButton = uibutton(grid, 'state', ...
                'Value', s.ModelShow, ...
                'Text', 'Show', ...
                'Tooltip', 'Plot the current tyre model curve.', ...
                'ValueChangedFcn', @obj.onSettingsChanged, ...
                'Tag', 'ModelShow');
            uilabel(grid, 'Text', 'Tire Model');

            obj.XAxisSettingDropDown = uidropdown(grid, ...
                'Items', obj.SteadyStateNamesAll, ...
                'Value', s.XAxis, ...
                'Tag', 'XAxis', ...
                'Tooltip', 'Quantity to sweep on the X-axis.', ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(grid, ...
                'Text', 'X-Axis', ...
                'Tag', 'XAxis');

            obj.YAxisSettingDropDown = uidropdown(grid, ...
                'Items', {'FX','FYW','MXW','MYW','MZW'}, ...
                'Tag', 'YAxis', ...
                'Tooltip', 'Force/moment to plot on the Y-axis.', ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(grid, ...
                'Text', 'Y-Axis');

            selector = ui.NumericRangeSelector(grid, ...
                'RangeChangedFcn', @obj.onXAxisRangeChanged);
            uilabel(grid, 'Text', 'X-Range');
            selector.Layout.Row = [0 1] + selector.Layout.Row;
            obj.XAxisRangeSelector = selector;
        end
        function setupSteadyStateSettingsPanel(obj)
            s = obj.Settings.Layout;
            w = s.DefaultButtonWidthTextIcon;
            grid = uigridlayout(obj.SteadyStateSettingsPanel, ...
                'RowHeight', repmat({'fit'}, 1, 6), ...
                'ColumnWidth', {'fit', w, 'fit'}, ...
                'ColumnSpacing', s.DefaultColumnSpacing, ...
                'Padding', s.DefaultPadding, ...
                'Scrollable', false);
            
            names = obj.SteadyStateNamesAll;
            units = obj.getUnitsFromNames(names);
            units = cellfun(@(x) sprintf('[%s]', x), units, ...
                'UniformOutput', false);
            
            for i = 1:numel(names)
                name = names{i};
                obj.SteadyStateSettingLabels(i) = uilabel(grid, ...
                    'Text', name);
                obj.SteadyStateSettingDropDowns(i) = uidropdown(grid, ...
                    'Editable', true, ...
                    'ValueChangedFcn', @obj.onSettingsChanged);
                uilabel(grid, 'Text', units{i}, ...
                    'HorizontalAlignment', 'center');
            end
            
            obj.SteadyStateSettingsPanelGrid = grid;
        end
        function setupSidePanel(obj)
            s = obj.Settings;
            obj.SidePanel = uipanel(obj.MainGrid);
            
            obj.SidePanelGrid = uigridlayout(obj.SidePanel, ...
                'RowHeight', repmat({'fit'}, 1, 2), ...
                'ColumnWidth', {'1x'}, ...
                'ColumnSpacing', 0, ...
                'Padding', zeros(1,4), ...
                'Scrollable', true);
            
            obj.PlotSettingsPanel = uipanel(obj.SidePanelGrid, ...
                'Title', 'Plot Settings', ...
                'FontWeight', s.Text.FontWeightPanel, ...
                'FontName', s.Text.FontNamePanel, ...
                'BorderType', 'none');
            
            obj.SteadyStateSettingsPanel = uipanel(obj.SidePanelGrid, ...
                'Title', 'Steady-State Settings', ...
                'FontWeight', s.Text.FontWeightPanel, ...
                'FontName', s.Text.FontNamePanel, ...
                'BorderType', 'none');
        end
        function setupAxes(obj)
            ax = uiaxes(obj.MainGrid);
            ax.Title.String = '';
            xlabel(ax, 'LONGSLIP / 1')
            ylabel(ax, 'FX / N')
            grid(ax, 'on')
            hold(ax, 'on')
            obj.Axes = ax;
            ax.Layout.Column = 1;
        end
        function setupListeners(obj)
            addlistener(obj, 'TyreModelChanged', @obj.onModelChanged);
            addlistener(obj, 'TyreDataChanged', @obj.onDataChanged);
            obj.ViewSettingsChangedListener = listener(...
                obj.Settings.View.TyreAnalysisPanel, 'SettingsChanged', ...
                @(~,~) obj.update());
        end
    end
    methods (Access = protected)
        function setup(obj)
            set(obj, 'Position', [0 0 800 400])
            obj.Settings = settings.AppSettings();
            obj.MainGrid = helpers.plotPanelMainGrid(obj, ...
                obj.Settings.Layout);
            setupAxes(obj)
            setupSidePanel(obj)
            setupPlotSettingsPanel(obj)
            setupSteadyStateSettingsPanel(obj)
            setupListeners(obj)
        end
        function update(obj)
            helpers.applySidebarLayout(obj.SidePanel, obj.Axes, ...
                obj.Settings.View.TyreAnalysisPanel.ShowSidebar);
            updatePlotSettings(obj)
            updateDropDowns(obj)
            updateXAxisRangeSelector(obj)
        end
    end
end
