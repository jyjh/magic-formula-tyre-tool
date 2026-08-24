classdef TyreFitterSolverSettingsPanel < matlab.ui.componentcontainer.ComponentContainer
    %FITTERSOLVERSETTINGSPANEL Panel to configure optimization settings of
    %fitter (fmincon).

    events (HasCallbackProperty, NotifyAccess = protected)
        SettingsChanged
    end
    
    properties (Access = private, Transient, NonCopyable)
        Panel                       matlab.ui.container.Panel
        Grid                        matlab.ui.container.GridLayout
        AlgorithmDropdown           matlab.ui.control.DropDown
        MaxFunEvalEditField         matlab.ui.control.NumericEditField
        MaxIterEditField            matlab.ui.control.NumericEditField
        StepToleranceEditField      matlab.ui.control.NumericEditField
        ParpoolButton               matlab.ui.control.StateButton
        DownsampleFactorSpinner     matlab.ui.control.Spinner
    end
    
    properties (Dependent, Access = public)
        OptimizerOptions struct
    end
    
    properties (Access = private)
        Settings settings.AppSettings
    end
    
    methods
        function value = get.OptimizerOptions(obj)
            value = obj.Settings.Fitter.OptimizerSettings;
        end
        function set.OptimizerOptions(obj, value)
            obj.Settings.Fitter.OptimizerSettings = value;
        end
    end
    
    methods (Access = private)
        function onSettingsChanged(obj, ~, ~)
            opts = obj.OptimizerOptions;
            s = obj.Settings.Fitter;
            try
                algorithm = obj.AlgorithmDropdown.Value;
                opts.Algorithm = algorithm;
                s.OptimizerSettings.Algorithm = opts.Algorithm;

                maxFunEval = obj.MaxFunEvalEditField.Value;
                opts.MaxFunctionEvaluations = maxFunEval;
                s.OptimizerSettings.MaxFunctionEvaluations = maxFunEval;

                maxIter = obj.MaxIterEditField.Value;
                opts.MaxIterations =  maxIter;
                s.OptimizerSettings.MaxIterations = maxIter;

                stepTol = obj.StepToleranceEditField.Value;
                opts.StepTolerance = stepTol;
                s.OptimizerSettings.StepTolerance = stepTol;

                useParallel = logical(obj.ParpoolButton.Value);
                opts.UseParallel = useParallel;
                s.OptimizerSettings.UseParallel = useParallel;

                downsampleFactor = obj.DownsampleFactorSpinner.Value;
                s.DownsampleFactor = downsampleFactor;
            catch cause
                exception = MException(...
                    'MagicFormulaTyreTool:InvalidSolverOptions', ...
                    'Invalid solver options entered by user.');
                exception = addCause(exception, cause);
                throw(exception)
            end
            e = events.FitterSettingsChangedEventData(opts);
            obj.OptimizerOptions = opts;
            notify(obj, 'SettingsChanged', e)
        end
    end
    
    methods (Access = protected)
        function setup(obj)
            obj.Settings = settings.AppSettings();
            obj.Position = [0 0 400 400];
            if isempty(obj.OptimizerOptions)
                opts = magicformula.v61.Fitter.initOptimizerOptions();
                obj.OptimizerOptions = opts;
            end

            g = uigridlayout(obj, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', zeros(1,4));
            obj.Panel = uipanel(g, ...
                'Title', 'Optimization Settings', ...
                'FontWeight', settings.TextSettings.FontWeightPanel, ...
                'FontName', settings.TextSettings.FontNamePanel, ...
                'BorderType', 'none');
            obj.Grid = uigridlayout(obj.Panel, ...
                'RowHeight', repmat({settings.LayoutSettings.DefaultButtonHeight}, 1, 6), ...
                'ColumnWidth', {'1x','fit'}, ...
                'Padding', settings.LayoutSettings.DefaultPadding, ...
                'ColumnSpacing', settings.LayoutSettings.DefaultColumnSpacing);
            
            algorithms = {
                'interior-point'
                'sqp'
                'active-set'
                };
            obj.AlgorithmDropdown = uidropdown(obj.Grid, ...
                'Items', algorithms, ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'Algorithm');
            
            obj.MaxFunEvalEditField = uieditfield(obj.Grid, 'numeric', ...
                'Limits', [1 inf], ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'MaxFunEvals');
            
            obj.MaxIterEditField = uieditfield(obj.Grid, 'numeric', ...
                'Limits', [1 inf], ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'MaxIter');
            
            obj.StepToleranceEditField = uieditfield(obj.Grid, 'numeric', ...
                'Limits', [0 inf], ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'StepTolerance');

            obj.ParpoolButton = uibutton(obj.Grid, 'state', ...
                'Text', 'Enable', ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'UseParallel');

            tooltip = 'Increase downsampling to reduce fit time.';
            obj.DownsampleFactorSpinner = uispinner(obj.Grid, ...
                'Limits', [1 1E5], ...
                'Tooltip', tooltip, ...
                'ValueChangedFcn', @obj.onSettingsChanged);
            uilabel(obj.Grid, 'Text', 'Downsampling', ...
                'Tooltip', tooltip);
        end
        function update(obj)
            s = obj.Settings.Fitter;
            opts = obj.OptimizerOptions;
            if isfield(opts, 'Algorithm') || isprop(opts, 'Algorithm')
                obj.AlgorithmDropdown.Value = opts.Algorithm;
            end
            if isfield(opts, 'MaxFunctionEvaluations') || isprop(opts, 'MaxFunctionEvaluations')
                obj.MaxFunEvalEditField.Value = opts.MaxFunctionEvaluations;
            end
            if isfield(opts, 'MaxIterations') || isprop(opts, 'MaxIterations')
                obj.MaxIterEditField.Value = opts.MaxIterations;
            end
            if isfield(opts, 'StepTolerance') || isprop(opts, 'StepTolerance')
                obj.StepToleranceEditField.Value = opts.StepTolerance;
            else
                obj.StepToleranceEditField.Value = 1e-6;
            end
            if isfield(opts, 'UseParallel') || isprop(opts, 'UseParallel')
                obj.ParpoolButton.Value = opts.UseParallel;
            end
            obj.DownsampleFactorSpinner.Value = s.DownsampleFactor;
        end
    end
end
