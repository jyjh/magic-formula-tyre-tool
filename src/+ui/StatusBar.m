classdef StatusBar < matlab.ui.componentcontainer.ComponentContainer
    %STATUSBAR Single-line status bar rendered at the bottom of the figure.
    %Holds a message with an optional success/warning/error icon. The host
    %can arm an auto-clear via setStatus; the timer is owned by the host so
    %it can be cancelled on the next setStatus call.

    properties
        Text char = char.empty
    end

    properties (Access = public, Transient, NonCopyable)
        %Icon name (bare svg filename resolved on the app path) or empty.
        Icon char = char.empty
    end

    properties (Access = private, Transient, NonCopyable)
        Grid  matlab.ui.container.GridLayout
        Image matlab.ui.control.Image
        Label matlab.ui.control.Label
    end

    properties (Access = private)
        Settings settings.AppSettings
    end

    methods (Access = protected)
        function setup(obj)
            obj.Settings = settings.AppSettings();
            obj.Grid = uigridlayout(obj, ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {obj.Settings.Layout.DefaultButtonWidthOnlyIcon, '1x'}, ...
                'ColumnSpacing', 5, ...
                'Padding', 4*ones(1,4));
            obj.Image = uiimage(obj.Grid, ...
                'Visible', 'off');
            obj.Label = uilabel(obj.Grid, ...
                'Text', obj.Text);
            obj.Label.Layout.Column = 2;
        end
        function update(obj)
            obj.Label.Text = obj.Text;
            if isempty(obj.Icon)
                obj.Image.Visible = 'off';
            else
                obj.Image.ImageSource = obj.Icon;
                obj.Image.Visible = 'on';
            end
        end
    end
end
