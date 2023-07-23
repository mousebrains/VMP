function x=separ(lat1,lon1,lat2,lon2);

% function dist=separ(lat1,lon1,lat2,lon2);
%
% separ - computes the separation in km between 2 lat-long positions
% uses program sep.m 

if (nargin==4)
 n1=length(lat1);
 n2=length(lat2);
 if (n1==n2)
  for k=1:n1
   x(k)=sep([lat1(k),lat2(k)],[lon1(k),lon2(k)]);
   end
  elseif (n1>1&n2==1)
  for k=1:n1
   x(k)=sep([lat1(k),lat2(1)],[lon1(k),lon2(1)]);
   end
  elseif (n2>1&n1==1)
  for k=1:n2
   x(k)=sep([lat1(1),lat2(k)],[lon1(1),lon2(k)]);
   end
 end
end
x=x./1000;%units are km
