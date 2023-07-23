% Check if the lhs file is newer than the rhs file

function q = isnewer(lhs, rhs, rinfo)
q = exist(lhs, "file");;
if ~q, return; end
linfo = dir(lhs);
if nargin < 3, rinfo = dir(rhs); end
q = linfo.datenum > rinfo.datenum;
end % if isnewer