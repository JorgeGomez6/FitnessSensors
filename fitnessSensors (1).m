classdef fitnessSensors < handle

    properties
        AccelerationSignal; % Acceleration signal
        VelocitySignal; % Velocity Signal
        TargetSignal; % Target Signal
        TargetSignalTs; % Time stamp Signal
        TimeHistory;
        Latitude;
        Longitude;
        Speed;
        Course;
        Altitude;
        HorizontalAccuracy;
        Axes;
        SavePlot;

        LatHistory double = [];   % Stores all latitude samples
        LonHistory double = [];   % Stores all longitude samples

        T;

        IsWorkoutActive logical = false;
        IsPaused logical = false;
        
    end
    
    properties(Access=private)
        mobileDevConnection;
    end
    
    methods
    
        function obj = fitnessSensors()
            
            if ~isempty(obj.mobileDevConnection)
                fprintf('Mobile device connection %s, is ready.\n',... 
                     obj.mobileDevConnection.Device);
            elseif isempty(obj.mobileDevConnection)
                % the phone connection
                obj.mobileDevConnection = mobiledev;
            else
                error(['Mobile device connection failed. Ensure ' ...
                    'the MATLAB app is open on your phone...\n']);
            end
        end

        function logSensorData(obj, hours, minutes, seconds)
            timeSeconds = (hours * 3600) + (minutes * 60) + seconds;
            if timeSeconds > 0
                fprintf("Starting workout for %d hours, %d minutes, and %d seconds...\n", hours, minutes, seconds);
            end

            fprintf('\n Start \n')
            
            obj.mobileDevConnection.Logging = 1;
            pause(timeSeconds);
            obj.mobileDevConnection.Logging = 0;

            fprintf('\n Done \n')

        end

        function setTargetSignal(obj, signalName)
            
            [A, t] = accellog(obj.mobileDevConnection);
            [V, ts] = angvellog(obj.mobileDevConnection);
            [obj.Latitude, obj.Longitude, timestamp, obj.Speed, obj.Course, obj.Altitude, obj.HorizontalAccuracy] = poslog(obj.mobileDevConnection);
            
            obj.LatHistory = obj.Latitude;
            obj.LonHistory = obj.Longitude;

            if isempty(A) || isempty(V) || isempty(obj.LatHistory) || isempty(t) || size(A,1) == 0
                error('No sensor data found. Collect data first.');
            end

            obj.TargetSignalTs = t;
            obj.TimeHistory = datetime("now");
            obj.AccelerationSignal = A; 
            obj.VelocitySignal = V; 
        end
        
        function geoPlotLine(obj, UIAxes)
            % Create a UI figure
            uif = uifigure('Name','Running Map');

            % Create 2D interactive geoaxes
            ax = geoaxes(uif, 'Basemap', 'streets');  % or 'satellite', 'topographic', etc.

            if isempty(obj.LatHistory)
                error("No location data. Start logging first.");
            end
            
            n = min(length(obj.LatHistory), length(obj.LonHistory));
            obj.LatHistory = obj.LatHistory(1:n);
            obj.LonHistory = obj.LonHistory(1:n);

            % plot the initial track
            obj.SavePlot = geoplot(ax, obj.LatHistory, obj.LonHistory, 'r-', 'LineWidth', 2);

            % set starting view
            geolimits(ax, ...
                [obj.LatHistory(end)-0.005, obj.LatHistory(end)+0.005], ...
                [obj.LonHistory(end)-0.005, obj.LonHistory(end)+0.005]);

            % timer fires every 1 second
            obj.T = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", 1, ...
                "TimerFcn", @(~,~) obj.timerUpdate() );
        end    

        %start/pause/stop logic
        
        function start(obj)
            if obj.IsWorkoutActive && ~obj.IsPaused
                fprintf("Workout is already running.\n");
                return;
            end

            obj.mobileDevConnection.Logging = 1;

            obj.IsWorkoutActive = true;
            obj.IsPaused = false;

            if ~isempty(obj.T) && isvalid(obj.T)
                start(obj.T);
            end

            fprintf("Workout has begun.\n");
        end

        function pause(obj)
            if ~obj.IsWorkoutActive
                fprintf("Workout must be active to pause.\n");
                return;
            end

            obj.mobileDevConnection.Logging = 0;
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
            end

            obj.IsPaused = true;
            fprintf("Workout paused.\n");
        end

        function stop(obj)
            if ~obj.IsWorkoutActive
                fprintf("Workout must be active to stop.\n");
                return;
            end

            obj.mobileDevConnection.Logging = 0;
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
            end

            obj.IsWorkoutActive = false;
            obj.IsPaused = false;
            fprintf("Workout stopped.\n");
        end

        %timer callback
        function timerUpdate(obj)
            if ~obj.IsWorkoutActive || obj.IsPaused
                return;
            [lat, lon] = poslog(obj.mobileDevConnection);
            end

            if isempty(lat)
                return;
            end

            % append to route
            obj.LatHistory(end+1) = lat(end);
            obj.LonHistory(end+1) = lon(end);

            % update the line data
            obj.SavePlot.LatitudeData = obj.LatHistory;
            obj.SavePlot.LongitudeData = obj.LonHistory;

            % auto-recenter with ~10% margin
            latMin = min(obj.LatHistory);
            latMax = max(obj.LatHistory);
            lonMin = min(obj.LonHistory);
            lonMax = max(obj.LonHistory);

            dLat = (latMax - latMin) * 0.1;
            dLon = (lonMax - lonMin) * 0.1;

            geolimits(obj.Axes, [latMin-dLat, latMax+dLat], [lonMin-dLon, lonMax+dLon]);
        end
        
        function getMaxValues
            max(abs(obj.AccelerationSignal))
            max(abs(obj.VelocitySignal))
        end
            
        function saveWorkoutFiles(obj)
            i = 1;
            filename = 'Workout ' + string(i);
            saveas(obj.SavePlot,filename, 'png');
            i = i + 1;
        end
    end
end
