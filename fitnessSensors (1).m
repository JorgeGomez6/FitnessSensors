classdef fitnessSensors < handle
    properties
        AccelerationSignal; % Acceleration signal
        VelocitySignal; % Velocity Signal
        PositionSignal; % Latitude/Longitude Signal
        TargetSignal; % Target Signal
        TargetSignalTs; % Time stamp Signal
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
            obj.AccelerationSignal = A; 
            obj.VelocitySignal = V; 
            obj.PositionSignal = [lat, lon, timestamp, speed, course, alt, horizacc ];

        end
        function geoPlotLine(obj, axes)
        
            lat = obj.positionSignal(:,1);
            lon = obj.positionSignal(:,2);
            
            if isempty(obj.TargetSignal)
                error('No target to plot');
            else
                geobasemap(axes, 'streets');
                geolimits(axes, [lat-0.005 lat+0.005], [lon-0.005 lon+0.005]);
                geoplot(axes, lat, lon, 'r-', LineWidth=2);
            end
        end
        function saveWorkoutFiles(obj)
            i = 1;
            filename = 'workout' + string(i);
            saveas(fig,filename, 'png');
            i = i + 1;
        end
    end
end
