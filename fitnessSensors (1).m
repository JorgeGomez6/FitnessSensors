classdef fitnessSensors < handle

    properties
        AccelerationSignal; % Acceleration signal
        VelocitySignal; % Velocity Signal
        TargetSignal; % Target Signal
        TargetSignalTs; % Time stamp Signal
        TimeHistory;
        Latitude;
        Longitude;
        TimeStamp;
        Speed;
        Course;
        Altitude;
        HorizontalAccuracy;
        Axes;
        SavePlot;

        LatHistory double = [];   % stores latitude samples
        LonHistory double = [];   % stores longitude samples
        SpeedHistory double = []; % stores speed samples
        AltitudeHistory double = []; % stores elevation samples

        SpeedAxes;
        ElevationAxes;
        SpeedLine;
        ElevationLine;
        StatsTable;


        T;

        IsWorkoutActive logical = false;
        IsPaused logical = false;
        
    end
    
    properties(Access=private, Transient = true)
        mobileDevConnection;
    end
    
    methods
    
        function obj = fitnessSensors()

            if isempty(obj.mobileDevConnection)
                obj.mobileDevConnection = mobiledev;
            end

            if ~isempty(obj.mobileDevConnection)
                disp("Mobile device connected.");
            else
                error(['Mobile device connection failed. Ensure ' ...
                    'the MATLAB app is open on your phone...\n']);
            end
        end

        % live chart & stats logic
        function setupLiveDisplays(obj, speedAxes, elevationAxes, statsTable)
            obj.SpeedAxes = speedAxes;
            obj.ElevationAxes = elevationAxes;
            obj.StatsTable = statsTable;

            % elevation plot
            hold(obj.ElevationAxes, "on");
            obj.ElevationLine = plot(obj.ElevationAxes, obj.TimeStamp, obj.Altitude, 'LineWidth', 1.5);
            title(obj.ElevationAxes, "Elevation vs Time");
            xlabel(obj.ElevationAxes, "Time (s)");
            ylabel(obj.ElevationAxes, "Elevation");
            

            % speed plot    
            hold(obj.SpeedAxes, "on");
            obj.SpeedLine = plot(obj.SpeedAxes, obj.TimeStamp, obj.Speed, 'LineWidth', 1.5);
            title(obj.SpeedAxes, "Speed vs Time");
            xlabel(obj.SpeedAxes, "Time (s)");
            ylabel(obj.SpeedAxes, "Speed");
            


            % stats
            obj.StatsTable.ColumnName = {'Statistic', 'Value'};
            obj.StatsTable.Data = {};
        end
       

        %start/pause/stop logic
        
        function start(obj, hours, minutes, seconds)
            
            if obj.IsWorkoutActive && ~obj.IsPaused
                fprintf("Workout is already running.\n");
                return;
            end

            timeSeconds = (hours * 3600) + (minutes * 60) + seconds;

            if timeSeconds > 0
                fprintf("Starting workout for %d hours, %d minutes, and %d seconds...\n", hours, minutes, seconds);
            else
                fprintf("Starting workout with no time limit...\n");
            end

            obj.mobileDevConnection.AccelerationSensorEnabled = 1;
            obj.mobileDevConnection.AngularVelocitySensorEnabled = 1;
            obj.mobileDevConnection.PositionSensorEnabled = 1;
            
            obj.mobileDevConnection.Logging = 1;
            obj.IsWorkoutActive = true;
            obj.IsPaused = false;

            obj.IsWorkoutActive = true;
            obj.IsPaused = false;

            if ~isempty(obj.T) && isvalid(obj.T) && strcmp(obj.T.Running,"off")
                start(obj.T);
            end

            fprintf("Workout has begun.\n");

            % If a positive duration was given, schedule auto‑stop
            if timeSeconds > 0
                stopTimer = timer( ...
                    "ExecutionMode","singleShot", ...
                    "StartDelay", timeSeconds, ...
                    "TimerFcn", @(~,~) obj.stop() );
                start(stopTimer);
                % clean up after firing
                stopTimer.StopFcn = @(~,~) delete(stopTimer);
            end

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

            obj.T = [];

            try
                clear obj.mobileDevConnection;
            catch
                obj.mobileDevConnection = [];
            end

            obj.IsWorkoutActive = false;
            obj.IsPaused = false;
            fprintf("Workout stopped.\n");
        end
        
        %timer callback
        function timerUpdatePos(obj)
            if ~obj.IsWorkoutActive || obj.IsPaused
                return;
            end
            [lat, lon, timestamp, speed, ~, alt, ~] = poslog(obj.mobileDevConnection);

            if isempty(lat)
                return;
            end

            obj.TimeStamp = timestamp(:).';
            obj.Speed = speed(:).';
            obj.Altitude = alt(:).';

            % append to route
            obj.LatHistory = lat(:).';
            obj.LonHistory = lon(:).';

            % update the line data
            if ~isempty(obj.SavePlot) && isvalid(obj.SavePlot)
                obj.SavePlot.LatitudeData = obj.LatHistory;
                obj.SavePlot.LongitudeData = obj.LonHistory;
            end

            % auto-recenter with ~10% margin
            latMin = min(obj.LatHistory);
            latMax = max(obj.LatHistory);
            lonMin = min(obj.LonHistory);
            lonMax = max(obj.LonHistory);

            dLat = (latMax - latMin) * 0.1;
            dLon = (lonMax - lonMin) * 0.1;

            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                geolimits(obj.Axes, [latMin-dLat, latMax+dLat], [lonMin-dLon, lonMax+dLon]);
            end

            obj.updatePlotsAndStats();
        end
        
        % map

        function geoPlot(obj, Panel)

            % Create 2D interactive geoaxes
            gx = geoaxes(Panel, 'Basemap', 'streets');  % or 'satellite', 'topographic', etc.
            obj.Axes = gx;


            obj.SavePlot = geoplot(obj.Axes, NaN, NaN, 'r-', 'LineWidth', 2);


        end

        function geoPlotLine(obj)

            % Timer fires every second
            obj.T = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", 1, ...
                "TimerFcn", @(~,~) obj.timerUpdate() );
            start(obj.T);

            % set starting view
            if size(obj.LatHistory) == 1
                geolimits(obj.Axes, ...
                [obj.LatHistory(end)-100, obj.LatHistory(end)+100], ...
                [obj.LonHistory(end)-100, obj.LonHistory(end)+100]);
            end
            
        end
        
        function setTargetSignal(obj)

            [A, t] = accellog(obj.mobileDevConnection);
            [V, ~] = angvellog(obj.mobileDevConnection);
            [~, ~, ~, obj.Speed, obj.Course, obj.Altitude, obj.HorizontalAccuracy] = poslog(obj.mobileDevConnection);

            obj.TargetSignalTs = t;
            obj.AccelerationSignal = A; 
            obj.VelocitySignal = V; 
        end

        function getMaxValues(obj)
            max(abs(obj.AccelerationSignal))
            max(abs(obj.VelocitySignal))
        end
            
        function saveWorkoutFiles(obj)
            i = 1;
            filename = 'Workout ' + string(i);
            saveas(obj.SavePlot,filename, 'png');
            i = i + 1;
        end

        function delete(obj)
            % Kill timer if it exists
            try
                if ~isempty(obj.T) && isvalid(obj.T)
                    stop(obj.T);
                    delete(obj.T);
                end
            end

            % Disconnect mobile device cleanly
            try
                if ~isempty(obj.mobileDevConnection)
                    disconnect(obj.mobileDevConnection);
                end
            end
        end
    end
end
