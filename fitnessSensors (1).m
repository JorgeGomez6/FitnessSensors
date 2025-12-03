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

        function logSensorData(obj, timeAmount, timeUnits, delaySeconds)

            timeUnits = string(timeUnits);

            if timeAmount > 0
                fprintf("Starting workout for %d %s...\n", timeAmount, timeUnits);
            end

            for ii = delaySeconds:-1:1
                fprintf("%d \n", ii)
                pause(1);
            end


            fprintf('\n Start \n')


            if timeUnits == 'hours'
                timeSeconds = timeAmount * 3600; % Convert hours to seconds
            elseif timeUnits == 'minutes'
                timeSeconds = timeAmount * 60; % Convert minutes to seconds
            end

            obj.mobileDevConnection.Logging = 1;
            pause(5)
                %timeSeconds);
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

            geoplot(lat,lon,"r-")
            geobasemap streets
            

        end
        function plotTargetSignal(obj, axes, titleStr)
            
            if isempty(obj.TargetSignal)
                error('No target to plot')
            else
                newTitleStr = string(titleStr);
                titleStrPretty = 'Acceleration signal: ' + newTitleStr;

                % fix so that every time you integrate it changes the name
                % of the obj.targetSignalName
                
                obj.targetSignalName = newTitleStr;
                plot(axes, obj.TargetSignalTs, obj.TargetSignal);
                ylabel(axes, titleStrPretty);
                xlabel(axes, 'time(s)');
                title(axes, titleStrPretty);
            end
        end
        function saveWorkoutFiles(obj, )
            saveas(fig,filename, 'png')
            
    end
end