% Join two tables together based on keys

function lhs = myJoiner(lhs, rhs, keys, names)
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