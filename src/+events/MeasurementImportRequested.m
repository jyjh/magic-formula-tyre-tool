classdef (ConstructOnLoad) MeasurementImportRequested < event.EventData
    properties
        Files cell
        Parser function_handle;
        SummaryTableFile char
        IgnoreC6MechanicalLimitBuckets logical
    end
    methods
        function eventData = MeasurementImportRequested(files, parser, ...
                summaryTableFile,ignoreC6MechanicalLimitBuckets)
            arguments
                files
                parser function_handle
                summaryTableFile char = char.empty
                ignoreC6MechanicalLimitBuckets (1,1) logical = false
            end
            eventData.Files = cellstr(files);
            eventData.Parser = parser;
            eventData.SummaryTableFile = summaryTableFile;
            eventData.IgnoreC6MechanicalLimitBuckets = ...
                ignoreC6MechanicalLimitBuckets;
        end
    end
end
