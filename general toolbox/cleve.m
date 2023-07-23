function rgb_colormap=cleve(n,gamma,omega)

%.. function rgb_colormap=cleve(n,gamma,omega)
%.. create colormap for matlab following Steve Pierce's 
%.. Cleveland 4,8, and 16 color pallettes for gri
%.. n == 4,8,or 16 number of color steps
%.. gamma == brightness (value) factor
%.. omega == minimum saturation
%.. gamma and omega are optional, set to 1. and 0.

        h1=0.5;   %.. cyan hue
	h2=5./6.; %.. magenta hue
	satur=1.0; %.. initial saturation
        if nargin==1;gamma=1.;omega=0.;end
	bright=.74*gamma; %.. initial brightness (value)
        delbri = (.98-bright)/(n/2);
	delsat = (satur-omega)/(n/2);
	
%	if n==4; delsat = 0.4; delbri = (.98-bright)/(n/2);end;
%	if n==8; delsat = 0.2; delbri = (.98-bright)/(n/2);end;
%	if n==16;delsat = 0.1; delbri = (.98-bright)/(n/2);end;

	for l=1:n/2
	  hsv_colormap(l,:)=[h1 satur bright];
	  satur=satur-delsat;bright=bright+delbri;
	end
	for l=n/2+1:n
	  satur=satur+delsat;bright=bright-delbri;
	  hsv_colormap(l,:)=[h2 satur bright];
	end
	
	rgb_colormap=hsv2rgb(hsv_colormap);	  
	      
%.. steve's original gri/mawk script
%gri:`Set image colorscale Cleveland 4'
%gri:{
%gri:    open "\.awk. 'BEGIN {\
%gri:        h1=0.5; satur=1.0; bright=0.74;\
%gri:        h2=0.833; delsat = 0.4; delbri = 0.12;\
%gri:        for(j=0;j<2;j++){\
%gri:            for(i=0;i<64;i++)print h1,satur,bright ;\
%gri:            satur -= delsat; bright += delbri;\
%gri:        }\
%gri:        for(j=0;j<2;j++){\
%gri:            satur += delsat; bright -= delbri;\
%gri:            for(i=0;i<64;i++)print h2,satur,bright ;\
%gri:        }\
%gri:    }' |"
%gri:    read image colorscale hsb
%gri:}
