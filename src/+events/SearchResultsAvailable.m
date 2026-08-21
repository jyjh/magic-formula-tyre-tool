classdef (ConstructOnLoad) SearchResultsAvailable < event.EventData
   properties
      SearchIndices (:,2)
   end
   methods
       function e = SearchResultsAvailable(indices)
           e.SearchIndices = indices;
      end
   end
end
