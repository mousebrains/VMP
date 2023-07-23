% Class holding the GPS time series for estimating a position
classdef GPSfromMat
    properties
        tbl
        method
    	Value {mustBeNumeric}
    end

    methods
        function obj = GPSfromMat(fn, method)
            arguments
	        fn string
		method string
	    end % arguments
%%
            a = load(fn).gps;
            [t, ix] = unique(a.t);
            tbl = timetable(t);
            tbl.lat = a.lat(ix);
            tbl.lon = a.lon(ix);
            obj.tbl = tbl;
            obj.method = method;
        end % GPSfromMat

    	function val = lat(obj, t)
            val = interp1(obj.tbl.t, obj.tbl.lat, t, obj.method, "extrap");
        end % lat

        function val = lon(obj, t)
            val = interp1(obj.tbl.t, obj.tbl.lon, t, obj.method, "extrap");
        end % lon

        function val = dt(obj, t)
            tNearest = interp1(obj.tbl.t, obj.tbl.t, t, "nearest", "extrap");
            val = abs(seconds(tNearest - t));
        end % dt
    end % methods
end % classdef
