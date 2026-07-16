classdef (Sealed) MagicFormulaTyreTool < matlab.apps.AppBase
    %MagicFormulaTyreTool MATLAB GUI for Magic Formula Tyre Modeling.
    %   https://github.com/teasit/magic-formula-tyre-tool
    
    properties (Access = private)
        TyreModel MagicFormulaTyre = MagicFormulaTyre.empty()
        TyreModelBackup MagicFormulaTyre = MagicFormulaTyre.empty()
        TyreModelFitted MagicFormulaTyre = MagicFormulaTyre.empty()
        TyreMeasurements tydex.Measurement
        TyreMeasurementsSelected tydex.Measurement
        TyreMeasurementsSelectionIndices logical
        TyreModelFitter magicformula.v61.Fitter

        %Cache of the last downsampled measurement array used for fitting.
        %It is invalidated explicitly when source data is assigned and keyed
        %only by downsample factor between assignments.
        TyreMeasurementsDownsampledFactor double = NaN
        TyreMeasurementsDownsampled tydex.Measurement = tydex.Measurement.empty
        
        %App settings, e.g. state of table filters
        Settings settings.AppSettings
        ViewLayoutSettingsChangedListener event.listener
        FitterSettingsChangedListener event.listener
    end
    properties (Access = private)
        %Stores about configuration values, e.g. application version.
        About struct = MagicFormulaTyreTool.initAboutConfiguration()
    end
    properties (Transient, Access = private)
        %If user selects a directory, it is saved and reused to accelerate
        %following user actions.
        LastUsedDirectoryByUser char
    end
    properties (Access = private)
        UIFigure                matlab.ui.Figure
        TabGroupPrimary         matlab.ui.container.TabGroup
        TabGroupSecondary       matlab.ui.container.TabGroup
        GridMain                matlab.ui.container.GridLayout
        
        FileMenu                matlab.ui.container.Menu
        FitterMenu              matlab.ui.container.Menu
        HelpMenu                matlab.ui.container.Menu
        ViewMenu                matlab.ui.container.Menu
        SelectFitModesMenu      matlab.ui.container.Menu
        
        TyreModelFittingTab     matlab.ui.container.Tab
        TyreModelPanel          ui.TyreModelPanel
        TyreModelGrid           matlab.ui.container.GridLayout
        
        TyreDataTab             matlab.ui.container.Tab
        TyreDataTabGrid         matlab.ui.container.GridLayout
        TyreDataPanel           ui.TyreDataPanel
        
        TyreModelAnalysisTab    matlab.ui.container.Tab
        TyreModelAnalysisGrid   matlab.ui.container.GridLayout
        TyreAnalysisPanel       ui.TyreAnalysisPanel
    end
    methods (Static, Access = private)
        function config = initAboutConfiguration()
            file = 'about.json';
            text = fileread(file);
            config = jsondecode(text);
        end
        function file = dialogSaveTyreModel(model)
            filter = '.tir';
            defname = 'magicformula.tir';
            prompt = 'Choose name for Tyre Properties File';
            [fileName, path] = uiputfile(filter, prompt, defname);
            if path == 0
                file = char.empty;
                return
            end
            file = fullfile(path, fileName);
            try
                model.saveTIR(file);
            catch sourceException
                baseException = exceptions.CouldNotExportTIR(fileName);
                baseException = addCause(baseException, sourceException);
                throw(baseException)
            end
        end
    end
    methods (Access = private)
        function params = extractNominalParametersFromMeasurements(app)
            measurements = app.TyreMeasurements;
            if isempty(measurements)
                params = [];
                return
            end
            params = measurements(end).ModelParameters;
        end
        function dialogApplyParamsFromMeasurements(app, params)
            fig = app.UIFigure;
            
            numParams = numel(params);
            paramStrings = cell(numParams,1);
            for i = 1:numParams
                p = params(i);
                str = sprintf('%s = %d%s', p.Name, p.Value, p.Unit);
                paramStrings{i,1} = str;
            end
            
            msgParams = strjoin(paramStrings, '\n');
            msg = sprintf(['The following parameters were detected ' ...
                'automatically in the loaded measurements: \n\n%s\n\n' ...
                'Do you want to apply these values to your model?'], ...
                msgParams);
            optApply = 'Apply';
            optCancel = 'No';
            userSelection = uiconfirm(fig, msg, ...
                'Parameters detected in measurements', ...
                'Options', {optApply, optCancel}, ...
                'DefaultOption', optApply, ...
                'CancelOption', optCancel);
            
            switch userSelection
                case optApply
                    model = app.TyreModel;
                    for i = 1:numel(params)
                        name = params(i).Name;
                        value = params(i).Value;
                        model.Parameters.(name).Value = value;
                    end
                    app.TyreModel = model;
                case optCancel
                    return
            end
        end
        function verifyMatlabVersion(app)
            releaseCreated = app.About.CreatedWithRelease;
            appName = app.About.Name;
            isOlder = isMATLABReleaseOlderThan(releaseCreated);
            if isOlder
                releaseInstalled = version('-release');
                msg = ['''%s'' was developed with ''%s''. ' ...
                    'The app might not work correctly with ''%s''.' ...
                    newline()];
                warning(msg, appName, releaseCreated, releaseInstalled)
            end
        end
    end
    methods (Access = private)
        function onKeyPress(app, ~, e)
            notify(app.TyreModelPanel, 'KeyPressed', e)
        end
        function onUiFigureSizeChanged(app, ~, ~)
            position = app.UIFigure.Position;
            width = position(3);
            height = position(4);
            % todo: do stuff here
        end
        function onUiFigureCloseRequest(app, ~, ~)
            fig = app.UIFigure;
            optionExit = 'Close';
            optionReturn = 'Return';
            options = {optionExit, optionReturn};
            message = ['Do you really want to close the App?' newline() ...
                'Unsaved progress will be lost.'];
            option = uiconfirm(fig, message, 'Close App', 'icon', 'warning', ...
                'Options', options, 'DefaultOption', optionReturn);
            switch option
                case optionReturn
                    return
                case optionExit
                    delete(app)
            end
        end
        function onCheckUpdates(app, ~, ~)
            fig = app.UIFigure;
            title = 'Check for Updates';
            versionCurrent = app.About.Version;
            try
                [available, versionLatest] = ...
                    helpers.checkUpdateAvailable(versionCurrent);
            catch
                icon = 'error';
                message = ['Could not check for updates.\n' ...
                    'Internet connection available?'];
                uialert(fig, message, title, 'icon', icon)
                return
            end
                
            if ~available
                message = 'The latest version is already installed (%s).';
                message = sprintf(message, versionCurrent);
                uialert(fig, message, title, 'icon', 'success')
                return
            end
            
            optionGitHub = 'GitHub Releases';
            optionFileExchange = 'FileExchange';
            optionCancel = 'Cancel';
            options = {optionFileExchange, optionGitHub, optionCancel};
            message = 'Update from %s to %s available.';
            message = sprintf(message, versionCurrent, versionLatest);
            message = [message newline() newline() ...
                'Note that for the latest GitHub release to show up on ' ...
                'FileExchange, expect a delay of up to an hour.'];
            selection = uiconfirm(fig, message, title, 'icon', 'info', ...
                'Options', options, 'DefaultOption', optionFileExchange);
            switch selection
                case optionGitHub
                    url = [app.About.Source '/releases/latest'];
                    web(url)
                case optionFileExchange
                    url = app.About.FileExchange;
                    web(url, '-new')
                case optionCancel
                    return
            end
        end
        function onTyreModelEdited(app, ~, ~)
            model = app.TyreModel;
            evtdata = events.ModelChangedEventData(model);
            notify(app.TyreAnalysisPanel, 'TyreModelChanged', evtdata)
        end
        function onSelectFitModesMenuSelected(app, source, ~)
            [fitmodes, fitmodeNames] = enumeration('magicformula.FitMode');
            fitmodeName = source.Text;
            I = strcmp(fitmodeNames, fitmodeName);
            fitmode = fitmodes(I);
            enable = ~logical(source.Checked);
            fitmodesEnabled = app.Settings.Fitter.FitModes;
            if enable
                fitmodesEnabled = [fitmodesEnabled fitmode];
                fitmodesEnabled = sort(fitmodesEnabled);
                fitmodesEnabled = unique(fitmodesEnabled);
            else
                I = fitmodesEnabled == fitmode;
                fitmodesEnabled(I) = [];
            end
            app.Settings.Fitter.FitModes = fitmodesEnabled;
            source.Checked = matlab.lang.OnOffSwitchState(enable);
        end
        function onLoadModelRequested(app, ~, ~)
            [fileName, path] = uigetfile('.tir', ...
                'Select Tyre Properties File');
            userCanceled = path == 0;  
            if userCanceled
                return
            end
            
            file = fullfile(path, fileName);
            try
                model = MagicFormulaTyre(file);
                app.setTyreModel(model)
            catch cause
                exception = exceptions.CouldNotImportTIR(fileName);
                exception = addCause(exception, cause);
                throw(exception)
            end
        end
        function onClearModelRequested(app, ~, ~)
            delete(app.TyreModel)
            delete(app.TyreModelBackup)
            modelEmpty = MagicFormulaTyre.empty;
            app.setTyreModel(modelEmpty)
        end
        function onImportMeasurementsRequested(app, ~, event)
            fig = app.UIFigure;
            title = 'Measurement Import';
            try
                files = event.Files;
                if isempty(files)
                    return
                end
                parserHandle = event.Parser;
                app.runMeasurementImport(files, parserHandle)
                app.recordLastSessionMeasurementFiles(files)
                app.Settings.LastSession.MeasurementParser = func2str(parserHandle);
                uialert(fig, 'Import successful.', title, 'Icon', 'success')
            catch cause
                msg = 'Import failed. See console/logfile for details';
                uialert(fig, msg, title, 'Icon', 'error')

                exception = exceptions.CouldNotImportTYDEX();
                exception = exception.addCause(cause);
                throw(exception)
            end
        end
        function runMeasurementImport(app, files, parser)
            %RUNMEASUREMENTIMPORT Parse measurement files, load them, and
            %apply derived nominal parameters to the current model. Shared
            %by the interactive import path and the last-session reopen on
            %startup so both behave identically.
            arguments
                app
                files cell
                parser function_handle
            end
            fig = app.UIFigure;
            title = 'Measurement Import';
            msg = 'Importing measurements...'; %TODO: not indeterminate
            dlg = uiprogressdlg(fig, ...
                'Title', title,...
                'Message', msg, ...
                'Indeterminate','on', ...
                'Cancelable', 'off');
            cleanup = onCleanup(@() close(dlg));
            measurements = app.TyreMeasurements;
            parserInstance = parser();
            for i = 1:numel(files)
                file = files{i};
                measurement = parserInstance.run(file);
                measurements = [measurements measurement];
            end
            app.setTyreMeasurementData(measurements)
            model = app.TyreModel;
            if ~isempty(model)
                nominalParams = app.extractNominalParametersFromMeasurements();
                app.dialogApplyParamsFromMeasurements(nominalParams)
            end
            notify(app.TyreDataPanel, 'MeasurementDataImportFinished')
        end
        function recordLastSessionMeasurementFiles(app, files)
            %RECORDLASTSESSIONMEASUREMENTFILES Append the given paths to the
            %cumulative last-session set (deduplicated, order preserved)
            %and persist them so they can be re-imported on the next launch.
            stored = app.getLastSessionMeasurementFiles();
            combined = [stored; files(:)];
            if ~isempty(combined)
                [~, ia] = unique(combined, 'stable');
                combined = combined(ia);
            end
            if isempty(combined)
                joined = char.empty;
            else
                joined = strjoin(combined, newline);
            end
            app.Settings.LastSession.MeasurementFiles = joined;
        end
        function files = getLastSessionMeasurementFiles(app)
            %GETLASTSESSIONMEASUREMENTFILES Return the remembered
            %measurement file paths from the last session as a cell array.
            s = app.Settings.LastSession.MeasurementFiles;
            if isempty(s)
                files = {};
            else
                files = cellstr(splitlines(s));
            end
        end
        function promptLoadLastSessionMeasurementData(app)
            %PROMPTLOADLASTSESSIONMEASUREMENTDATA Ask the user whether to
            %re-import the measurement data files from the last session,
            %and do so with the remembered parser on acceptance. No-op
            %when nothing is remembered. Mirrors the last-tyre-model
            %reopen: silent on success, uialert on failure.
            files = app.getLastSessionMeasurementFiles();
            if isempty(files)
                return
            end
            fig = app.UIFigure;
            title = 'Load Last Measurement Data';
            n = numel(files);
            if n == 1
                noun = 'measurement file';
            else
                noun = 'measurement files';
            end
            parserStr = app.Settings.LastSession.MeasurementParser;
            fileList = strjoin(files, newline);
            if isempty(parserStr)
                message = sprintf(['Do you want to re-import the ' ...
                    'following %d %s from last session?\n\n%s'], ...
                    n, noun, fileList);
            else
                message = sprintf(['Do you want to re-import the ' ...
                    'following %d %s from last session using parser ' ...
                    '''%s''?\n\n%s'], n, noun, parserStr, fileList);
            end
            selection = uiconfirm(fig, message, title, ...
                'icon', 'info', 'Options', {'Yes', 'Cancel'});
            if ~strcmp(selection, 'Yes')
                return
            end
            if isempty(parserStr)
                [~, parserHandles] = helpers.getParsers();
                parserHandle = parserHandles{1};
            else
                parserHandle = str2func(parserStr);
            end
            try
                app.runMeasurementImport(files, parserHandle)
            catch
                uialert(fig, 'Failed to load last measurement data!', ...
                    title, 'Icon', 'error')
            end
        end
        function onExportMeasurementsRequested(app, ~, ~)
            measurements = app.TyreMeasurements;
            
            if isempty(measurements)
                return
            end
            
            opendir = app.LastUsedDirectoryByUser;
            title = 'Select Export Directory for TYDEX Measurement Files';
            savedir = uigetdir(opendir, title);
            if savedir == 0
                return
            end
            app.LastUsedDirectoryByUser = savedir;
            
            title = 'Export Measurements';
            fig = app.UIFigure;
            msg = ['Exporting measurements as TYDEX files to the ' ...
                'following directory:' ...
                sprintf('\n\t%s', savedir)];
            dlg = uiprogressdlg(fig, ...
                'Title', title,...
                'Message', msg, ...
                'Indeterminate','on', ...
                'Cancelable', 'off');
            
            try
                measurements.save(savedir)
            catch cause
                close(dlg)
                msg = 'Export failed. See console/logfile for details';
                uialert(fig, msg, title, 'Icon', 'error')
                
                exception = exceptions.CouldNotExportTYDEX();
                exception = exception.addCause(cause);
                throw(exception)
            end
            msg = 'Export successful.';
            uialert(fig, msg, title, 'Icon', 'success')
        end
        function onClearMeasurementsRequested(app, ~, ~)
            message = 'Clear loaded measurements?';
            title = 'Clear Data';
            optionClearAll = 'Clear All';
            optionClearSelected = 'Clear Selected';
            optionCancel = 'Cancel';
            options = {optionClearSelected, optionClearAll, optionCancel};
            selection = uiconfirm(app.UIFigure, message, title, ...
                'Icon', 'info', ...
                'Options', options, ...
                'DefaultOption', optionCancel, ...
                'CancelOption', optionCancel);
            switch selection
                case optionCancel
                    return
                case optionClearAll
                    measurementsNew = tydex.Measurement.empty;
                    app.Settings.LastSession.MeasurementFiles = char.empty;
                    app.Settings.LastSession.MeasurementParser = char.empty;
                case optionClearSelected
                    I = app.TyreMeasurementsSelectionIndices;
                    measurements = app.TyreMeasurements;
                    measurements(I) = [];
                    measurementsNew = measurements;
            end
            app.setTyreMeasurementData(measurementsNew)
        end
        function onAboutDialogRequested(app, ~, ~)
            fig = app.UIFigure;
            title = 'About';
            about = app.About;
            fn = fieldnames(about);
            message = char.empty;
            for i = 1:numel(fn)
                if i ~= 1
                    message = [message newline()];
                end
                field = fn{i};
                value = about.(field);
                if iscell(value)
                    paragraph = [
                        field ':' newline() ...
                        sprintf('\t - %s\n', value{:})
                        ];
                else
                    paragraph = [field ': ' value newline()];
                end
                message = [message paragraph];
            end
            uialert(fig, message, title, 'Icon', 'info')
        end
        function onResetApplicationRequested(app, ~, ~)
            message = 'Unsaved progress and App settings will be reset.';
            title = 'Reset Application';
            optionReset = 'Reset';
            optionCancel = 'Cancel';
            options = {optionReset, optionCancel};
            selection=  uiconfirm(app.UIFigure, message, title, ...
                'Icon', 'warning', 'Options', options);
            switch selection
                case optionCancel
                    return
            end
            
            reset(app)
        end
        function onFitterSettingsChanged(app, ~, ~)
            fitmodes = app.Settings.Fitter.FitModes;
            menus = app.SelectFitModesMenu.Children;
            menuTexts = {menus.Text};
            set(menus, 'Checked', 'off')
            for i = 1:numel(fitmodes)
                fitmodeName = char(fitmodes(i));
                I = strcmp(menuTexts, {fitmodeName});
                menus(I).Checked = 'on';
            end
        end
        function onFitterMeasurementsLoaded(app, ~, event)
            arguments
                app
                ~
                event events.FitterMeasurementsLoadedEventData
            end
            flagsMap = event.FitModeFlags;
            app.TyreDataPanel.addMeasurementFitModes(flagsMap);
        end
        function onStartFittingRequested(app, ~, ~)
            import magicformula.FitMode
            
            fig = app.UIFigure;
            title = 'Tyre Model Fitter';
            msg = sprintf(['To start fitting, the following conditions ' ...
                'must be met:' newline() ...
                '\t- Tyre model loaded' newline() ...
                '\t- Tyre data loaded' newline() ...
                '\t- Fit modes selected (Fx0, Fy0, Fx, ...)']);
            showUserFail = @(x) uialert(fig, msg, title, 'Icon', 'error');
            
            tyreModel = app.TyreModel;
            if isempty(tyreModel)
                showUserFail()
                return
            end
            
            tyreModelFitted = copy(tyreModel);
            params = tyreModel.Parameters;
            measurements = app.TyreMeasurements;
            fitmodes = app.Settings.Fitter.FitModes;
            
            if isempty(params) || isempty(measurements) || isempty(fitmodes)
                showUserFail()
                return
            end
            
            downsampleFactor = app.Settings.Fitter.DownsampleFactor;
            % This cache is invalidated explicitly whenever source data is
            % assigned. Avoid sampled fingerprints: edited data can have the
            % same size and sampled values while requiring a fresh fit.
            if app.TyreMeasurementsDownsampledFactor == downsampleFactor ...
                    && ~isempty(app.TyreMeasurementsDownsampled)
                measurements = app.TyreMeasurementsDownsampled;
            else
                measurements = measurements.downsample(downsampleFactor, 0);
                app.TyreMeasurementsDownsampledFactor = downsampleFactor;
                app.TyreMeasurementsDownsampled = measurements;
            end

            fitter = app.TyreModelFitter;
            fitter.Parameters = params;
            fitter.Measurements = measurements;
            fitter.FitModes = fitmodes;
            
            msg = 'Starting Fitter...';
            dlg = uiprogressdlg(fig, ...
                'Title', title, ...
                'Message', msg, ...
                'Indeterminate','on', ...
                'CancelText', 'Stop', ...
                'Cancelable', 'on');
            
            outputFcn = @(x,optimValues,state) ...
                helpers.fitterOutputFcn(x,optimValues,state,dlg,fitter);
            fitter.Options.OutputFcn = outputFcn;
            
            try
                fitter.run()
                
                paramsFitted = fitter.ParametersFitted;
                tyreModelFitted.Parameters = paramsFitted;
                app.TyreModelFitted = tyreModelFitted;
                
                
                e = events.TyreModelFitterFinished(paramsFitted);
                notify(app.TyreModelPanel, 'TyreModelFitterFinished', e)
                
                cancelByUser = dlg.CancelRequested;
                close(dlg)
                
                if cancelByUser
                    msg = 'Fitting process aborted by user.';
                    icon = 'info';
                else
                    msg = 'Fitting process successful.';
                    icon = 'success';
                end
                results = fitter.FitResults;
                if ~isempty(results)
                    summary = arrayfun(@(r) sprintf( ...
                        '%s: RMSE %.4g, exit %d, %d evals', ...
                        char(r.FitMode),r.NormalizedRMSE,r.ExitFlag, ...
                        r.FunctionEvaluations),results,'UniformOutput',false);
                    msg = [msg newline() strjoin(summary,newline())];
                end
                msg = [msg newline() ...
                    'Parameters of last iteration written to table.' ...
                    newline() newline() ...
                    'Details printed to logfile/console.'];
                uialert(fig, msg, title, 'icon', icon)
            catch ME
                % Fall back to the last successfully fitted values so that
                % a single failed fit does not wipe the table. If no fit
                % has ever succeeded, the payload stays empty.
                if isempty(app.TyreModelFitted)
                    paramsFitted = magicformula.v61.Parameters.empty;
                else
                    paramsFitted = app.TyreModelFitted.Parameters;
                end
                e = events.TyreModelFitterFinished(paramsFitted);
                notify(app.TyreModelPanel, 'TyreModelFitterFinished', e)

                cancelRequested = dlg.CancelRequested;
                close(dlg)
                
                cause = ME.cause;
                if iscell(cause)
                    cause = cause{1};
                end
                
                msg = ['Fitting process FAILED!' newline() newline()];
                if cancelRequested
                    msg = 'Fitting process aborted by user; fitted parameters were not applied.';
                elseif any(strcmp(cause.identifier,{ ...
                        'MagicFormulaTyreLibrary:InvalidMeasurementData', ...
                        'MagicFormulaTyreLibrary:UnsupportedSolverAlgorithm', ...
                        'MagicFormulaTyreLibrary:SolverDidNotConverge'}))
                    msg = [msg 'Cause:' newline() cause.message];
                else
                    switch class(cause)
                        case 'magicformula.exceptions.EmptyMeasurementChannel'
                            msg = [msg 'Cause:' newline() ...
                                'Loaded measurements do not have data ' ...
                                'for channel ''%s''.'];
                            msg = sprintf(msg, cause.Channel);
                        case 'magicformula.exceptions.NoMeasurementForFitMode'
                            msg = [msg 'Cause:' newline() ...
                                'Loaded measurements do not contain ' ...
                                'data for selected fitmode ''%s''. ' ...
                                newline() newline() ...
                                'Troubleshooting:' newline() ...
                                'Note that to fit ''Fx0'' ' ...
                                'you require data that includes slip ratio ' ...
                                'sweeps. Fitting ''Fx'' also requires slip ' ...
                                'angle to be present during those sweeps. ' ...
                                'Similarly, fitting ''Fy0'' requires slip ' ...
                                'angle sweeps and ''Fy'' also requires ' ...
                                'those sweeps at interval-fixed slip ratios.'];
                            msg = sprintf(msg, cause.FitMode);
                        otherwise
                            msg = [msg 'Details printed to logfile/console.'];
                    end
                end
                if ~isempty(app.TyreModelFitted)
                    msg = [msg newline() ...
                        'Previously fitted values retained in the table.'];
                end
                uialert(fig, msg, title, 'icon', 'error')
                rethrow(ME)
            end
        end
        function onNewTyreModelRequested(app, ~, ~)
            model = app.TyreModel;
            if ~isempty(model)
                message = 'Current tyre model will be deleted. Continue?';
                title = 'New Tyre Model';
                optYes = 'Yes';
                optCancel = 'Cancel';
                options = {optYes, optCancel};
                selection = uiconfirm(app.UIFigure, message, title, ...
                    'Options', options, 'Icon', 'warning');
                if strcmp(selection, optCancel)
                    return
                end
            end
            
            modelNew = MagicFormulaTyre();
            file = MagicFormulaTyreTool.dialogSaveTyreModel(modelNew);
            if isempty(file)
                return
            end
            app.setTyreModel(modelNew)
            modelNew.File = file;
        end
        function onSaveTyreModelRequested(app, ~, ~)
            model = app.TyreModel;
            if isempty(model)
                return
            end
            
            file = model.File;
            if isempty(file)
                app.setTyreModel(model)
                model = app.TyreModel;
                file = MagicFormulaTyreTool.dialogSaveTyreModel(model);
                model.File = file;
                return
            end
            
            optOverwrite = 'Overwrite';
            optNew = 'Save as...';
            optCancel = 'Cancel';
            options = {optOverwrite, optNew, optCancel};
            message = 'Imported file will be overwritten. Continue?';
            title = 'Save Tyre Model';
            selection = uiconfirm(app.UIFigure, message, title, ...
                'Options', options, 'Icon', 'warning');
            
            switch selection
                case optCancel
                    return
                case optOverwrite
                    model.saveTIR(file);
                case optNew
                    file = MagicFormulaTyreTool.dialogSaveTyreModel(model);
                    model.File = file;
            end
        end
        function onResetTyreModelRequested(app, ~, ~)
            backupModel = app.TyreModelBackup;
            
            message = 'Unsaved changes will be discarded. Continue?';
            title = 'Reset Tyre Model';
            options = {'Yes', 'Cancel'};
            selection = uiconfirm(app.UIFigure, message, title, ...
                'Icon', 'warning', 'Options', options);
            userCancel = strcmp(selection, options{end});
            if userCancel
                return
            end
            
            app.setTyreModel(backupModel)
        end
        function onClearTyreModelRequested(app, ~, ~)
            model = app.TyreModel;
            modelBackup = app.TyreModelBackup;
            
            % Compare parameter values, not object identity: setTyreModel
            % always copy()s, so the two handles are never the same object.
            if ~isempty(model) && ~isempty(modelBackup)
                hasUnsavedChanges = ~isequal(struct(model.Parameters), struct(modelBackup.Parameters));
            else
                hasUnsavedChanges = false;
            end
            if hasUnsavedChanges
                message = 'Tyre model has unsaved changes. Continue?';
                title = 'Clear Tyre Model';
                options = {'Yes', 'Cancel'};
                selection=  uiconfirm(app.UIFigure, message, title, ...
                    'Icon', 'warning');
                userCancel = strcmp(selection, options{end});
                if userCancel
                    return
                end
            end
            
            model = MagicFormulaTyre.empty();
            app.setTyreModel(model)
        end
        function onViewMenuSelected(app, source, ~)
            viewSettings = app.Settings.View;           
            tag = source.Tag;
            tagParent = source.Parent.Tag;
            valueOld = logical(source.Checked);
            valueNew = ~valueOld;
            
            viewSettings.(tagParent).(tag) = valueNew;
            set(source, 'Checked', valueNew);
        end
        function onApplyFittedTyreModelRequested(app, ~, event)
            tyreModel = app.TyreModel;
            tyreModelFitted = app.TyreModelFitted;
            if isempty(tyreModelFitted)
                return
            end

            fig = app.UIFigure;
            msg = ['Do you want to apply the fitted parameter values? ' ...
                'Unsaved changes will be overwritten.'];
            optApplySelected = 'Apply Selected';
            optApplyAll = 'Apply All';
            optCancel = 'Cancel';
            userSelection = uiconfirm(fig, msg, ...
                'Parameters detected in measurements', ...
                'Options', {optApplyAll, optApplySelected, optCancel}, ...
                'DefaultOption', optApplyAll, ...
                'CancelOption', optCancel);
            switch userSelection
                case optApplyAll
                    app.setTyreModel(tyreModelFitted, false)
                case optApplySelected
                    names = event.ParameterNames;
                    for i = 1:numel(names)
                        name = names{i};
                        tyreModel.Parameters.(name).Value = ...
                            tyreModelFitted.Parameters.(name).Value;
                    end
                    app.setTyreModel(tyreModel, false)
                case optCancel
                    return
            end
        end
        function onZeroParametersRequested(app, ~, ~)
            tyreModel = app.TyreModel;
            if isempty(tyreModel)
                return
            end
            fig = app.UIFigure;
            msg = ['Set all fittable parameter values of the current ' ...
                'model to 0?\n\nUse ''Reset Model'' to revert to the ' ...
                'saved state.'];
            optZero = 'Zero Parameters';
            optCancel = 'Cancel';
            userSelection = uiconfirm(fig, msg, 'Zero Parameters', ...
                'Options', {optZero, optCancel}, ...
                'DefaultOption', optZero, ...
                'CancelOption', optCancel);
            if ~strcmp(userSelection, optZero)
                return
            end
            params = tyreModel.Parameters;
            names = fieldnames(params);
            for i = 1:numel(names)
                name = names{i};
                if isa(params.(name), 'magicformula.ParameterFittable')
                    params.(name).Value = 0;
                end
            end
            app.setTyreModel(tyreModel, false)
        end
        function onTyreModelStructToMatRequested(app, ~, ~)
            filter = '.mat';
            defname = 'mfparams.mat';
            prompt = 'Choose name for MAT file';
            [fileName, path] = uiputfile(filter, prompt, defname);
            if path == 0
                return
            end
            file = fullfile(path, fileName);
            mfparams = app.TyreModel.Parameters;
            mfparams = struct(mfparams);
            save(file, 'mfparams')
        end
        function onPlotTyreMeasurementsRequested(app, ~, event)
            measurements = event.Measurements;
            fig = app.UIFigure;
            title = 'Tyre Data Stacked Plot';
            if isempty(measurements)
                message = 'No measurements selected in table.';
                uialert(fig, message, title, 'Icon', 'info')
                return
            elseif numel(measurements) > 1
                message = ['Can only plot one measurement at a time.' ...
                    newline() 'Please select only one row in the table.'];
                uialert(fig, message, title, 'Icon', 'info')
                return
            end
            m = measurements;
            metadata = m.Metadata;
            I = strcmp({metadata.Name}, 'MEASID');
            measurementName = metadata(I).Value;
            
            measuredObjs = m.Measured;
            measuredNames = {measuredObjs.Name};
            I = strcmp(measuredNames, 'RUNTIME');
            measuredObjs(I) = [];
            measuredNames = {measuredObjs.Name};
            
            sz = [numel(m.RUNTIME) numel(measuredObjs)];
            type = class(m.RUNTIME);
            tbl = timetable('Size', sz, ...
                'VariableTypes', repmat({type}, [1 sz(2)]), ...
                'RowTimes', seconds(m.RUNTIME), ...
                'VariableNames', measuredNames);
            
            for i = 1:numel(measuredObjs)
                measured = measuredObjs(i);
                data = measured.Data;
                name = measured.Name;
                tbl.(name) = data;
            end
            
            f = figure('Name', measurementName);
            stackedplot(f, tbl, 'Marker', '.', 'LineStyle', 'none');
            grid on
        end
        function onMeasurementDataSelectionChanged(app, ~, event)
            measurements = event.Measurements;
            I = event.Indices;
            app.TyreMeasurementsSelected = measurements;
            app.TyreMeasurementsSelectionIndices = I;
        end
        function onViewLayoutSettingsChanged(app, ~, ~)
            s = app.Settings;
            if s.View.Layout.MoveAnalysisPanelToSecondaryTabGroup
                app.TabGroupSecondary = uitabgroup(app.GridMain);
                app.TabGroupPrimary.Layout.Column = 1;
                app.TyreModelAnalysisTab.Parent = app.TabGroupSecondary;
                app.TabGroupSecondary.Layout.Row = 1;
                app.TabGroupSecondary.Layout.Column = 2;
            else
                app.TyreModelAnalysisTab.Parent = app.TabGroupPrimary;
                delete(app.TabGroupSecondary)
                app.TabGroupPrimary.Layout.Column = [1 2];
            end
        end
    end
    methods (Access = private)
        function createComponents(app)
            if isempty(app.UIFigure)
                createUIFigure(app)
            end
            createGrid(app)
            createTabGroups(app)
            createTyreModelTab(app)
            createTyreDataTab(app)
            createTyreAnalysisTab(app)
            createMenus(app)
            set(app.UIFigure, 'Visible', 'on');
        end
        function createUIFigure(app)
            about = app.About;
            name = sprintf('%s %s', about.Name, about.Version);
            position = groot().ScreenSize;
            position(1:2) = position(3:4)*0.2;
            position(3:4) = position(3:4)*0.6;
            app.UIFigure = uifigure(...
                'Visible', 'off',...
                'Tag', 'MainUIFigure', ...
                'HandleVisibility', 'on', ...
                'Color', [1 1 1], ...
                'Position', position, ...
                'Name', name, ...
                'Icon', 'tyre_icon.png', ...
                'AutoResizeChildren', 'off', ...
                'SizeChangedFcn', @app.onUiFigureSizeChanged, ...
                'CloseRequestFcn', @app.onUiFigureCloseRequest, ...
                'KeyPressFcn', @app.onKeyPress);
        end
        function createGrid(app)
            app.GridMain = uigridlayout(app.UIFigure, ...
                'Padding', zeros(1,4), ...
                'RowSpacing', 0, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x','1x'}, ...
                'ColumnSpacing', 0);
        end
        function createTabGroups(app)
            app.TabGroupPrimary = uitabgroup(app.GridMain);
            s = app.Settings; 
            if s.View.Layout.MoveAnalysisPanelToSecondaryTabGroup
                app.TabGroupSecondary = uitabgroup(app.GridMain);
            else
                app.TabGroupPrimary.Layout.Column = [1 2];
            end
        end
        function createTyreModelTab(app)
            app.TyreModelFittingTab = uitab(app.TabGroupPrimary, ...
                'Title', 'Tyre Model');
            app.TyreModelGrid = uigridlayout(app.TyreModelFittingTab, ...
                'Padding', 10*ones(1,4), ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'});
            app.TyreModelPanel = ui.TyreModelPanel(app.TyreModelGrid, ...
                'LoadTyreModelDialogRequestedFcn', @app.onLoadModelRequested, ...
                'TyreModelResetRequestedFcn', @app.onResetTyreModelRequested, ...
                'TyreModelNewRequestedFcn', @app.onNewTyreModelRequested, ...
                'TyreModelSaveRequested', @app.onSaveTyreModelRequested, ...
                'TyreModelApplyFittedRequested', @app.onApplyFittedTyreModelRequested, ...
                'TyreModelZeroParametersRequestedFcn', @app.onZeroParametersRequested, ...
                'TyreModelStructToMatRequested', @app.onTyreModelStructToMatRequested, ...
                'TyreModelClearRequested', @app.onClearTyreModelRequested, ...
                'FitterStartRequestedFcn', @app.onStartFittingRequested, ...
                'TyreModelEditedFcn', @app.onTyreModelEdited);
        end
        function createTyreDataTab(app)
            app.TyreDataTab = uitab(...
                app.TabGroupPrimary, ...
                'Title', 'Tyre Data');
            app.TyreDataTabGrid = uigridlayout(...
                app.TyreDataTab, ...
                'Padding', 10*ones(1,4), ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'});
            app.TyreDataPanel = ui.TyreDataPanel(...
                app.TyreDataTabGrid, ...
                'MeasurementDataImportRequestedFcn', ...
                @app.onImportMeasurementsRequested, ...
                'MeasurementDataClearRequestedFcn', ...
                @app.onClearMeasurementsRequested, ...
                'MeasurementDataExportRequestedFcn', ...
                @app.onExportMeasurementsRequested, ...
                'PlotTyreMeasurementsRequestedFcn', ...
                @app.onPlotTyreMeasurementsRequested, ...
                'MeasurementDataSelectionChanged', ...
                @app.onMeasurementDataSelectionChanged);
        end
        function createTyreAnalysisTab(app)
            s = app.Settings;
            if s.View.Layout.MoveAnalysisPanelToSecondaryTabGroup
                parentTabGroup = app.TabGroupSecondary;
            else
                parentTabGroup = app.TabGroupPrimary;
            end
            app.TyreModelAnalysisTab = uitab(parentTabGroup, ...
                'Title', 'Tyre Analysis');
            app.TyreModelAnalysisGrid = uigridlayout(...
                app.TyreModelAnalysisTab, ...
                'Padding', 10*ones(1,4), ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'});
            app.TyreAnalysisPanel = ui.TyreAnalysisPanel(...
                app.TyreModelAnalysisGrid);
        end
        function createMenus(app)
            createFileMenu(app)
            createFitterMenu(app)
            createViewMenu(app)
            createHelpMenu(app)
        end
        function createFileMenu(app)
            app.FileMenu = uimenu(app.UIFigure, 'Text', 'File');
            uimenu(app.FileMenu, ...
                'Text', '&New Tyre Model', ...
                'Accelerator', 'N', ...
                'MenuSelectedFcn', @app.onNewTyreModelRequested);
            uimenu(app.FileMenu, ...
                'Text', '&Open Tyre Model', ...
                'Accelerator', 'O', ...
                'MenuSelectedFcn', @app.onLoadModelRequested);
            uimenu(app.FileMenu, ...
                'Text', '&Save Tyre Model', ...
                'Accelerator', 'S', ...
                'MenuSelectedFcn', @app.onSaveTyreModelRequested);
            uimenu(app.FileMenu, ...
                'Text', '&Clear Tyre Model', ...
                'MenuSelectedFcn', @app.onClearModelRequested);
            
            uimenu(app.FileMenu, ...
                'Text', '&Import Tyre Data', ...
                'Separator', 'on', ...
                'Accelerator', 'I', ...
                'MenuSelectedFcn', @app.onImportMeasurementsRequested);
            uimenu(app.FileMenu, ...
                'Text', 'Clear Tyre Data', ...
                'MenuSelectedFcn', @app.onClearMeasurementsRequested);
        end
        function createFitterMenu(app)
            app.FitterMenu = uimenu(app.UIFigure, 'Text', 'Fitter');
            app.SelectFitModesMenu = uimenu(app.FitterMenu, ...
                'Text', 'Select Fit-Modes', ...
                'Separator', 'on');
            fitmodesText = {'Fx0','Fy0','Mz0','Fx','Fy','Mx','My','Mz'};
            fitmodesSelected = cellstr(app.Settings.Fitter.FitModes);
            for i = 1:numel(fitmodesText)
                text = fitmodesText{i};
                checked = any(strcmpi(text, fitmodesSelected));
                uimenu(app.SelectFitModesMenu, 'Text', text, ...
                    'Checked', checked, ...
                    'MenuSelectedFcn', @app.onSelectFitModesMenuSelected);
            end
            
            uimenu(app.FitterMenu, ...
                'Text', 'Start &Fitter', ...
                'Accelerator', 'F', ...
                'MenuSelectedFcn', @app.onStartFittingRequested);
        end
        function createViewMenu(app)
            app.ViewMenu = uimenu(app.UIFigure, 'Text', 'View');
            s = app.Settings.View;
            
            m = uimenu(app.ViewMenu, ...
                'Text', 'Tyre Model Parameter Table', ...
                'Tag', 'TyreParametersTable');
            uimenu(m, ...
                'Text', 'Show Fittable Parameters', ...
                'Tag', 'ShowFittableParameters', ...
                'Checked', s.TyreParametersTable.ShowFittableParameters, ...
                'MenuSelectedFcn', @app.onViewMenuSelected);
            uimenu(m, ...
                'Text', 'Show Non-Fittable Parameters', ...
                'Tag', 'ShowNonFittableParameters', ...
                'Checked', s.TyreParametersTable.ShowNonFittableParameters, ...
                'MenuSelectedFcn', @app.onViewMenuSelected);
            uimenu(m, ...
                'Text', 'Show Only Fit-Mode Parameters', ...
                'Tag', 'ShowOnlyFitModeParameters', ...
                'Checked', s.TyreParametersTable.ShowOnlyFitModeParameters, ...
                'MenuSelectedFcn', @app.onViewMenuSelected);
            
            m = uimenu(app.ViewMenu, ...
                'Text', 'Layout', ...
                'Tag', 'Layout');
            uimenu(m, ...
                'Text', 'Analysis Tab on Secondary TabGroup', ...
                'Tag', 'MoveAnalysisPanelToSecondaryTabGroup', ...
                'Checked', s.Layout.MoveAnalysisPanelToSecondaryTabGroup, ...
                'MenuSelectedFcn', @app.onViewMenuSelected);

        end
        function createHelpMenu(app)
            app.HelpMenu = uimenu(app.UIFigure, 'Text', 'Help');
            uimenu(app.HelpMenu, ...
                'Text', 'About', ...
                'MenuSelectedFcn', @app.onAboutDialogRequested)
            uimenu(app.HelpMenu, ...
                'Text', 'Check for Updates', ...
                'MenuSelectedFcn', @app.onCheckUpdates)
            uimenu(app.HelpMenu, ...
                'Text', '&Reset Application', ...
                'Accelerator', 'R', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @app.onResetApplicationRequested)
        end
    end
    methods (Access = private)
        function initSettings(app)
            versionTool = app.About.Version;
            versionSettings = settings.AppSettings.version();
            versionsMatch = strcmpi(versionTool, versionSettings);
            if versionsMatch
                s = settings.AppSettings();
            else
                settings.AppSettings.clear()
                s = settings.AppSettings();
                s.Version = versionTool;
            end
            app.Settings = s;
        end
        function addlisteners(app)
            app.ViewLayoutSettingsChangedListener = listener(...
                app.Settings.View.Layout, 'SettingsChanged', ...
                @app.onViewLayoutSettingsChanged);
            app.FitterSettingsChangedListener = listener(...
                app.Settings.Fitter, 'SettingsChanged', ...
                @app.onFitterSettingsChanged);
        end
        function startupFcn(app)
            s = app.Settings;
            lastTyreFile = s.LastSession.TyreModelFile;
            if ~isempty(lastTyreFile)
                fig = app.UIFigure;
                title = 'Load Last Tyre Model';
                message = sprintf(['Do you want to load the following ' ...
                    'TIR file from last session?\n\n%s'], lastTyreFile);
                optionLoad = 'Yes';
                optionCancel = 'Cancel';
                options = {optionLoad, optionCancel};
                selection = uiconfirm(fig, message, title, ...
                    'icon', 'info', ...
                    'Options', options);
                switch selection
                    case optionLoad
                        try
                            model = MagicFormulaTyre(lastTyreFile);
                        catch
                            model = MagicFormulaTyre.empty;
                            message = 'Failed to load last tyre model!';
                            uialert(fig, message, title, 'Icon', 'error')
                        end
                    case optionCancel
                        model = MagicFormulaTyre.empty;
                end
            else
                model = MagicFormulaTyre.empty;
            end
            app.setTyreModel(model)
            
            fitter = magicformula.v61.Fitter();
            fitter.Options = s.Fitter.OptimizerSettings;
            app.TyreModelFitter = fitter;
            app.TyreModelPanel.Fitter = fitter;
            
            measurements = tydex.Measurement.empty();
            app.setTyreMeasurementData(measurements);

            %Offer to re-import the measurement data files from the last
            %session, mirroring the last-tyre-model reopen above.
            app.promptLoadLastSessionMeasurementData()

            addlisteners(app)
        end
        function setTyreModel(app, model, overwriteBackup)
            arguments
                app
                model MagicFormulaTyre
                overwriteBackup logical = true
            end
            if app.TyreModel ~= model
                delete(app.TyreModel)
            end
            modelCopy = copy(model);
            app.TyreModel = modelCopy;
            if overwriteBackup
                app.TyreModelBackup = model;
            end
            if isempty(model) 
                app.Settings.LastSession.TyreModelFile = char.empty;
            else
                app.Settings.LastSession.TyreModelFile = model.File;
            end
            e = events.ModelChangedEventData(modelCopy);
            notify(app.TyreModelPanel, 'TyreModelChanged', e)
            notify(app.TyreAnalysisPanel, 'TyreModelChanged', e)
            app.TyreModelPanel.Model = modelCopy;
        end
        function setTyreMeasurementData(app, measurements)
            fitter = app.TyreModelFitter;
            fitter.Measurements = measurements;
            flags = fitter.FitModeFlags;

            app.TyreMeasurements = measurements;
            app.TyreMeasurementsSelected = tydex.Measurement.empty;
            app.TyreMeasurementsSelectionIndices = logical.empty;

            % Invalidate the downsample cache: the source data changed, so
            % the next fit must rebuild the downsampled array.
            app.TyreMeasurementsDownsampledFactor = NaN;
            app.TyreMeasurementsDownsampled = tydex.Measurement.empty;

            e = events.TyreMeasurementsChanged(measurements, flags);
            notify(app.TyreDataPanel, 'MeasurementDataChanged', e);
            notify(app.TyreAnalysisPanel, 'TyreDataChanged', e);
        end
    end
    methods (Access = public)
        function reset(app)
            %RESET Resets application without closing current window.
            app.Settings.reset()
            
            fig = app.UIFigure;
            dlg = uiprogressdlg(fig, 'Title', 'Reset Application', ...
                'Message', 'Please wait.', 'Indeterminate', 'on');
            
            delete(fig.Children)
            
            metaClass = metaclass(app);
            metaProperties = metaClass.PropertyList;
            isTransient = [metaProperties.Transient];
            hasDefault = [metaProperties.HasDefault];
            isConstant = [metaProperties.Constant];
            I = ~isTransient & hasDefault & ~isConstant;
            metaProperties = metaProperties(I);
            for i = 1:numel(metaProperties)
                metaProperty = metaProperties(i);
                propName = metaProperty.Name;
                propDefault = metaProperty.DefaultValue;
                app.(propName) = propDefault;
            end
            
            createComponents(app)
            runStartupFcn(app, @startupFcn)
            
            close(dlg)
        end
        function app = MagicFormulaTyreTool
            verifyMatlabVersion(app);
            runningApp = getRunningApp(app);
            if isempty(runningApp)
                initSettings(app)
                createComponents(app)
                registerApp(app, app.UIFigure)
                runStartupFcn(app, @startupFcn)
            else
                figure(runningApp.UIFigure)
                app = runningApp;
            end
            
            if nargout == 0
                clear app
            end
        end
        function delete(app)
            if ~isempty(app.Settings)
                try
                    app.Settings.save()
                catch
                    warning('Failed to save settings to persistent storage.')
                end
            end
            delete(app.Settings)
            clear AppSettings
            delete(app.TyreModel)
            delete(app.TyreModelBackup)
            delete(app.TyreModelFitter)
            delete(app.UIFigure)
    end
    end
end
