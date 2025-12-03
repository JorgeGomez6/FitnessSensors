classdef fitnessSensors < handle
    properties
        AccelerationSignal; % Acceleration signal
        VelocitySignal; % Velocity Signal
        PositionSignal; % Latitude/Longitude Signal
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

        T;

        IsWorkoutActive logical = false;
        IsPaused logical = false;
        
    end
    properties(Access=private)
        mobileDevConnection;
    end
    
    methods
        function obj = fitnessSensors()

            % Log the mobile device connection

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
            [lat, lon, timestamp, speed, course, alt, horizacc] = poslog(obj.mobileDevConnection);
            


            if isempty(A) || isempty(V) || isempty(lat) || isempty(t) || size(A,1) == 0
                error('No sensor data found. Collect data first.');
            end

            obj.TargetSignalTs = t;
            obj.TimeHistory = datetime("now");
            obj.AccelerationSignal = A; 
            obj.VelocitySignal = V; 
            obj.Latitude = lat
            obj.Longitude = lon
            obj.Speed = speed
            obj.Course = course
            obj.Altitude = alt
            obj.HorizontalAccuracy = horizacc
        end
        function geoPlotLine(obj, UIAxes)
            obj.Axes = UIAxes
            lat = obj.positionSignal(:,1);
            lon = obj.positionSignal(:,2);
            
            if isempty(obj.TargetSignal)
                error('No target to plot');
            else
                geobasemap(obj.Axes, 'streets');
                geolimits(obj.Axes, [lat-0.005 lat+0.005], [lon-0.005 lon+0.005]);
                obj.SavePlot = geoplot(obj.Axes, lat, lon, 'r-', LineWidth=2);
                
                obj.T = timer("ExecutionMode", "fixedSpacing", "Period",1, ...
                "TimerFcn", @obj.timerUpdate);
            end
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
        end
        
        function getMaxValues
        end
            
        function saveWorkoutFiles(obj)
            i = 1;
            filename = 'Workout ' + string(i);
            saveas(obj.SavePlot,filename, 'png');
            i = i + 1;
        end
    end
end
