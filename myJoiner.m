% Join two tables together based on keys
%
% take variables from rhs if they exist in both lhs and rhs
%
% names are variables not included in join
%
% June-2023, Pat Welch, pat@mousebrains.com

function lhs = myJoiner(lhs, rhs, keys, names)
arguments
    lhs table
    rhs table
    keys (:,1) string
    names (:,1) string = strings(0,1)
end % arguments

if isempty(rhs), return; end

[~, iLeft, iRight] = outerjoin(lhs, rhs, "Keys", keys);
qJoint = iLeft ~= 0 & iRight ~= 0; % In both lhs and rhs
qRight = iLeft == 0 & iRight ~= 0; % In not in lhs but in rhs

if any(qJoint)
    names = setdiff(string(rhs.Properties.VariableNames), union(keys, names));
    lhs(iLeft(qJoint),names) = rhs(iRight(qJoint), names);
end % any qJoint

if any(qRight)
    lhs = [lhs; rhs(iRight(qRight),:)];
    lhs = sortrows(lhs, keys);
end % if any qRight
end % myJoiner