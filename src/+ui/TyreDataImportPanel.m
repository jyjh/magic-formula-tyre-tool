classdef TyreDataImportPanel < matlab.ui.componentcontainer.ComponentContainer
    %TYREDATAIMPORTPANEL User can select measurements to parse.
    events (HasCallbackProperty, NotifyAccess = protected)
        DataImportRequested
    end
    events (NotifyAccess = public)
        DataImportFinished
    end
    properties (Access = private, Transient, NonCopyable)
        Grid              matlab.ui.container.GridLayout
        Table             matlab.ui.control.Table
        TableRemoveButton matlab.ui.control.Button
        ParserDropDown    matlab.ui.control.DropDown
        SummaryTableField matlab.ui.control.EditField
        SummaryTableHint  ui.HelpHint
        IgnoreC6CheckBox  matlab.ui.control.CheckBox
    end
    properties (Access = public)
        Parser function_handle
        Parsers
        MeasurementFiles cell
        MeasurementFilesSelected cell
        SummaryTableFile char
        IgnoreC6MechanicalLimitBuckets logical = false
    end
    properties (Access = private)
        Settings settings.AppSettings
    end
    methods (Access = private)
        function onDataImportFinished(obj, ~, ~)
            obj.MeasurementFiles = {};
        end
        function onRunDataImportRequested(obj, ~, ~)
            files = obj.MeasurementFiles;
            if isempty(files)
                return
            end
            parser = obj.Parser;
            e = events.MeasurementImportRequested( ...
                files,parser,obj.SummaryTableFile, ...
                obj.IgnoreC6MechanicalLimitBuckets);
            notify(obj, 'DataImportRequested', e);
        end
        function onSelectDataFilesRequested(obj, ~, ~)
            filter = '.mat';
            prompt = 'Select measurement files';
            [filenames,folder] = uigetfile(filter, prompt, ...
                'MultiSelect', 'on');
            if folder == 0
                return
            end
            files = fullfile(folder, filenames);
            files = cellstr(files)';
            obj.MeasurementFiles = [obj.MeasurementFiles; files];
        end
        function onSelectParserDialog(obj, ~, ~)
            filter = '.m';
            prompt = 'Select parser class file';
            [fileName, folder] = uigetfile(filter, prompt);
            if folder == 0
                return
            end
            [~, fileBaseName] = fileparts(fileName);
            pathParts = strsplit(folder, filesep());
            I = cellfun(@(x) startsWith(x, '+'),  pathParts);
            pathToPackage = fullfile(pathParts{~I});
            addpath(pathToPackage)
            packageParts = pathParts(I);
            packageParts = erase(packageParts, '+');
            parserClassName = strjoin([packageParts fileBaseName], '.');
            
            superclassNames = superclasses(parserClassName);
            isParser = any(contains(superclassNames, 'tydex.Parser'));
            
            if ~isParser
                fig = ancestor(obj, 'figure');
                title = 'Select Parser';
                msg = 'Must be subclass of ''tydex.Parser''.';
                uialert(fig, msg, title, 'icon', 'error')
                return
            end
            
            parserName = [fileBaseName ' (custom)'];
            parserHandle = str2func(parserClassName);
            
            dd = obj.ParserDropDown;
            dd.Items = [{parserName} dd.Items];
            dd.ItemsData = [{parserHandle} dd.ItemsData];
            obj.Parser = parserHandle;
        end
        function onSelectSummaryTableRequested(obj, ~, ~)
            filter = {'*.xlsx','Excel workbooks (*.xlsx)'};
            prompt = 'Select FSAE TTC Summary Tables workbook';
            [fileName,folder] = uigetfile(filter,prompt);
            if folder == 0
                return
            end
            obj.SummaryTableFile = fullfile(folder,fileName);
        end
        function onClearSummaryTableRequested(obj, ~, ~)
            obj.SummaryTableFile = char.empty;
        end
        function onIgnoreC6Changed(obj, ~, event)
            obj.IgnoreC6MechanicalLimitBuckets = event.Value;
        end
        function onParserDropdownChangedFcn(obj, ~, event)
            obj.Parser = event.Value;
        end
        function onMeasurementFilesSelected(obj, table, event)
            if isempty(event.Indices)
                obj.MeasurementFilesSelected = [];
                return
            end
            rows = event.Indices(:,1);
            filesSelected = table.Data(rows);
            obj.MeasurementFilesSelected = filesSelected;
        end
        function onRemoveDataFiles(obj, ~, ~)
            files = obj.MeasurementFiles;
            filesToRemove = obj.MeasurementFilesSelected;
            I = ismember(files, filesToRemove);
            files(I) = [];
            obj.MeasurementFiles = files;
            obj.MeasurementFilesSelected = [];
        end
        function onOpenParserScript(obj, ~, ~)
            open(func2str(obj.Parser));
        end
    end

    methods (Access = protected)
        function setupSidebarPanel(obj)
            s = settings.LayoutSettings();
            g = uigridlayout(obj, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', zeros(1,4));
            p = uipanel(g, 'Title', char.empty);
            obj.Grid = uigridlayout(p, ...
                'RowHeight', {'fit', 'fit', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', zeros(1,4), ...
                'ColumnSpacing', s.DefaultColumnSpacing);
        end
        function setupParserPanel(obj)
            s = obj.Settings;
            p = uipanel(obj.Grid, ...
                'Title', 'Parser', ...
                'FontWeight', s.Text.FontWeightPanel, ...
                'BorderType', 'none');
            g = uigridlayout(p, ...
                'RowHeight', {s.Layout.DefaultButtonHeight, 'fit'}, ...
                'RowSpacing', s.Layout.DefaultRowSpacing, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', s.Layout.DefaultPadding);
            [parserNames, parserHandles] = helpers.getParsers();
            obj.ParserDropDown = uidropdown(g, ...
                'Items', parserNames, ...
                'ItemsData', parserHandles, ...
                'ValueChangedFcn', @obj.onParserDropdownChangedFcn);
            obj.Parser = parserHandles{1};
            w = s.Layout.DefaultButtonWidthOnlyText;
            g = uigridlayout(g, ...
                'RowHeight', {s.Layout.DefaultButtonHeight}, ...
                'ColumnWidth', {'1x', w, w}, ...
                'Padding', zeros(1,4));
            uilabel(g, 'Text', char.empty);
            uibutton(g, 'Text', 'Edit', ...
                'ButtonPushedFcn', @obj.onOpenParserScript);
            uibutton(g, 'Text', 'Add...', ...
                'ButtonPushedFcn', @obj.onSelectParserDialog);
        end
        function setupFilesPanel(obj)
            s = obj.Settings;
            p = uipanel(obj.Grid, ...
                'Title', 'Files', ...
                'FontWeight', s.Text.FontWeightPanel, ...
                'BorderType', 'none');
            g = uigridlayout(p, ...
                'RowHeight', {200, s.Layout.DefaultButtonHeight, ...
                    'fit',s.Layout.DefaultButtonHeight,'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', s.Layout.DefaultPadding);
            filesGrid = g;
            obj.Table = uitable(g, 'Data', {}, ...
                'ColumnName', [], 'RowName', [], ...
                'CellSelectionCallback', @obj.onMeasurementFilesSelected);
            w = s.Layout.DefaultButtonWidthOnlyText;
            g = uigridlayout(g, ...
                'ColumnWidth', {'1x', w, w}, ...
                'RowHeight', {s.Layout.DefaultButtonHeight}, ...
                'Padding', zeros(1,4), ...
                'ColumnSpacing', s.Layout.DefaultColumnSpacing);
            uilabel(g, 'Text', char.empty);
            obj.TableRemoveButton = uibutton(g, 'Text', 'Remove', ...
                'ButtonPushedFcn', @obj.onRemoveDataFiles);
            uibutton(g, 'Text', 'Add...', ...
                'ButtonPushedFcn', @obj.onSelectDataFilesRequested);

            summaryHintGrid = uigridlayout(filesGrid, ...
                'ColumnWidth',{'1x',s.Layout.DefaultButtonWidthOnlyIcon}, ...
                'RowHeight',{s.Layout.DefaultButtonHeight}, ...
                'Padding',zeros(1,4), ...
                'ColumnSpacing',0);
            uilabel(summaryHintGrid,'Text','FSAE TTC Summary Tables (recommended):');
            obj.SummaryTableHint = ui.HelpHint(summaryHintGrid, ...
                'Tooltip', ['The Summary Tables workbook supplied with ' ...
                    'each FSAE TTC test campaign. Selecting it enriches ' ...
                    'each run with run-condition metadata (pressure, ' ...
                    'load, camber, ...) so imported measurements carry ' ...
                    'their nominal parameters.'], ...
                'ClickedFcn', @(~,~) web('https://github.com/jyjh/magic-formula-tyre-tool'));
            metadataGrid = uigridlayout(filesGrid, ...
                'ColumnWidth',{'1x',w,w}, ...
                'RowHeight',{s.Layout.DefaultButtonHeight}, ...
                'Padding',zeros(1,4), ...
                'ColumnSpacing',s.Layout.DefaultColumnSpacing);
            obj.SummaryTableField = uieditfield(metadataGrid,'text', ...
                'Editable','off','Placeholder','No workbook selected');
            uibutton(metadataGrid,'Text','Clear', ...
                'ButtonPushedFcn',@obj.onClearSummaryTableRequested);
            uibutton(metadataGrid,'Text','Select...', ...
                'ButtonPushedFcn',@obj.onSelectSummaryTableRequested);
            obj.IgnoreC6CheckBox = uicheckbox(filesGrid, ...
                'Text','Ignore incomplete C6 mechanical-limit buckets', ...
                'Value',obj.IgnoreC6MechanicalLimitBuckets, ...
                'Tooltip',['For C6-flagged runs, exclude only condition ' ...
                'buckets that do not complete both directions of the ' ...
                'scheduled slip sweep.'], ...
                'ValueChangedFcn',@obj.onIgnoreC6Changed);
        end
        function setupImportButtonPanel(obj)
            s = obj.Settings;
            p = uipanel(obj.Grid, ...
                'Title', ' ', ...
                'FontWeight', s.Text.FontWeightPanel, ...
                'BorderType', 'none');
            g = uigridlayout(p, ...
                'RowHeight', {s.Layout.DefaultButtonHeight}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', s.Layout.DefaultPadding);
            uibutton(g, 'Text', 'Run Import', 'Icon', 'play-solid.svg',...
                'ButtonPushedFcn', @obj.onRunDataImportRequested);
        end
        function setupListeners(obj)
            addlistener(obj, 'DataImportFinished', ...
                @obj.onDataImportFinished);
        end
        function setup(obj)
            obj.Position = [0 0 300 400];
            obj.Settings = settings.AppSettings();
            obj.IgnoreC6MechanicalLimitBuckets = ...
                obj.Settings.LastSession.IgnoreC6MechanicalLimitBuckets;
            setupSidebarPanel(obj)
            setupFilesPanel(obj)
            setupParserPanel(obj)
            setupListeners(obj)
            setupImportButtonPanel(obj)
        end
        function update(obj)
            files = obj.MeasurementFiles;
            filesSelected = obj.MeasurementFilesSelected;
            obj.Table.Data = files;
            obj.ParserDropDown.Value = obj.Parser;
            obj.SummaryTableField.Value = obj.SummaryTableFile;
            obj.IgnoreC6CheckBox.Value = ...
                obj.IgnoreC6MechanicalLimitBuckets;
            obj.IgnoreC6CheckBox.Enable = matlab.lang.OnOffSwitchState( ...
                ~isempty(obj.SummaryTableFile));
            enable = matlab.lang.OnOffSwitchState(~isempty(filesSelected));
            obj.TableRemoveButton.Enable = enable;
        end
    end
end
