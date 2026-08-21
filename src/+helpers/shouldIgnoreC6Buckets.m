function tf = shouldIgnoreC6Buckets(flag, summaryTableFile)
%SHOULDIGNOREC6BUCKETS Resolve the C6 mechanical-limit-bucket filter.
%The bucket filter is only meaningful when a Summary Tables workbook is
%present, so the flag is masked by the workbook availability. Centralizing
%this rule keeps the interactive import path and the last-session reopen
%path in agreement.
arguments
    flag (1,1) logical
    summaryTableFile char
end
tf = flag && ~isempty(summaryTableFile);
end
