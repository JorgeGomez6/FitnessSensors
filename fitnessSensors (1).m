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

        function logSensorData(obj, timeAmount, timeUnits, timeSeconds)

            timeUnits = string(timeUnits);

            if timeAmount > 0
                fprintf("Starting workout for %d %s...\n", timeAmount, timeUnits);
            end

            fprintf('\n Start \n')


            if timeUnits == 'hours'
                timeSeconds = timeAmount * 3600; % Convert hours to seconds
            elseif timeUnits == 'minutes'
                timeSeconds = timeAmount * 60; % Convert minutes to seconds
            end

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
        function start(obj)
            start(obj.T);
        end

        function stop(obj)
            stop(obj.T);
        end
        
        function getMaxValues
            
        function saveWorkoutFiles(obj)
            i = 1;
            filename = 'Workout ' + string(i);
            saveas(obj.SavePlot,filename, 'png');
            i = i + 1;
        end
    end
end
