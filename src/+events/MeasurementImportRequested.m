classdef (ConstructOnLoad) MeasurementImportRequested < event.EventData
    properties
        Files cell
        Parser function_handle;
        SummaryTableFile char
    end
    methods
        function eventData = MeasurementImportRequested(files, parser, summaryTableFile)
            arguments
                files
                parser function_handle
                summaryTableFile char = char.empty
            end
            eventData.Files = cellstr(files);
            eventData.Parser = parser;
            eventData.SummaryTableFile = summaryTableFile;
        end
    end
end
