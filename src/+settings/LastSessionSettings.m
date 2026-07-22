classdef LastSessionSettings < settings.AbstractSettings
    properties (SetObservable, AbortSet)
        TyreModelFile char
        %Newline-joined full paths of the measurement files imported since
        %the last full clear; '' when none are remembered.
        MeasurementFiles char
        %Name of the parser class last used to import measurement files;
        %'' when none is remembered.
        MeasurementParser char
        %Optional companion FSAE TTC Summary Tables workbook.
        MeasurementSummaryTableFile char
    end
    methods
        function obj = LastSessionSettings()
        end
    end
end
