classdef fitnessSensors < handle

    properties
        Latitude double = [];
        Longitude double = [];
        TimeStamp;
        Speed;
        Elevation;

        Axes;
        GeoMapPlot;
        
        SpeedPlot;
        AVGSpeed;
        STDSpeed;
        ElevationGainLoss;
        TotalTime;

        ElevationPlot;
        SpeedAxes;
        ElevationAxes;
        StatsTable;

        T;
        StopTimer;

        WorkoutNames (1,:) string;        % Names shown in dropdown
        WorkoutData;                      % Struct array for each workout
        SaveFile = "workoutHistory.mat";  % Where permanent data is stored

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

        %start/pause/stop logic
        
        function start(obj, hours, minutes, seconds)

            % Timer fires every second
            obj.T = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", 1, ...
                "TimerFcn", @(~,~) obj.timerUpdatePos() );

           
            timeSeconds = (hours * 3600) + (minutes * 60) + seconds;

            if timeSeconds > 0
                fprintf("Starting workout for %d hours, %d minutes, and %d seconds...\n", hours, minutes, seconds);
            else
                fprintf("Starting workout with no time limit...\n");
            end
            
            obj.mobileDevConnection.Logging = 1;

            obj.IsWorkoutActive = true;
            obj.IsPaused = false;

            fprintf("Workout has begun.\n");

            % If a positive duration was given, schedule auto‑stop
            if timeSeconds > 0
                obj.StopTimer = timer( ...
                    "ExecutionMode","singleShot", ...
                    "StartDelay", timeSeconds, ...
                    "TimerFcn", @(~,~) obj.stop() );
                start(obj.StopTimer);
            end

        end

        function pause(obj)

            obj.mobileDevConnection.Logging = 0;
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
            end

            obj.IsPaused = true;
            fprintf("Workout paused.\n");
        end

        function stop(obj)

            obj.mobileDevConnection.Logging = 0;
            delete(timerfindall)
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
                delete(obj.T);
                obj.T = [];
            end

            if ~isempty(obj.StopTimer) && isvalid(obj.StopTimer)
                stop(obj.StopTimer);
                delete(obj.StopTimer);
                obj.StopTimer = [];
            end


            obj.IsWorkoutActive = false;
            obj.IsPaused = false;
            fprintf("Workout stopped.\n");
        end

        function reset(obj)

            if ~isempty(obj.mobileDevConnection)
                discardlogs(obj.mobileDevConnection);
            end

            % 1. Stop & delete timers
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
                delete(obj.T);
            end
            obj.T = [];

            if isprop(obj, "StopTimer") && ~isempty(obj.StopTimer) && isvalid(obj.StopTimer)
                stop(obj.StopTimer);
                delete(obj.StopTimer);
            end
            obj.StopTimer = [];

            % 3. Reset latest values
            obj.TimeStamp = [];
            obj.Speed = [];
            obj.Elevation = [];
            obj.Latitude = [];
            obj.Longitude = [];
            obj.AVGSpeed = [];
            obj.STDSpeed = [];
            obj.ElevationGainLoss = [];
            obj.TotalTime = [];

            % 4. Reset stats
            if ~isempty(obj.StatsTable)
                obj.StatsTable.Data = {};
            end

            % 5. Reset plots ONLY by clearing their data
            if ~isempty(obj.GeoMapPlot) && isvalid(obj.GeoMapPlot)
                obj.GeoMapPlot.LatitudeData = NaN;
                obj.GeoMapPlot.LongitudeData = NaN;
            end

            if ~isempty(obj.SpeedPlot) && isvalid(obj.SpeedPlot)
                obj.SpeedPlot.XData = NaN;
                obj.SpeedPlot.YData = NaN;
            end

            if ~isempty(obj.ElevationPlot) && isvalid(obj.ElevationPlot)
                obj.ElevationPlot.XData = NaN;
                obj.ElevationPlot.YData = NaN;
            end

            fprintf("Workout reset complete.\n");
        end
        
        %timer callback
        function timerUpdatePos(obj)

            % Make sure timer is still valid

            if ~obj.IsWorkoutActive || obj.IsPaused
                return;
            end
            [lat, lon, timestamp, speed, ~, alt, ~] = poslog(obj.mobileDevConnection);

            if isempty(lat)
                return;
            end

            obj.TimeStamp = timestamp(:).';
            obj.Speed = speed(:).';
            obj.Elevation = alt(:).';

            % append to route
            obj.Latitude = lat(:).';
            obj.Longitude = lon(:).';

            % update the line data
            if ~isempty(obj.GeoMapPlot) && isvalid(obj.GeoMapPlot)
                obj.GeoMapPlot.LatitudeData  = obj.Latitude;
                obj.GeoMapPlot.LongitudeData = obj.Longitude;
            end

            if ~isempty(speed)
                obj.SpeedPlot.XData = obj.TimeStamp;
                obj.SpeedPlot.YData = obj.Speed;
            end

            if ~isempty(alt)
                obj.ElevationPlot.XData = obj.TimeStamp;
                obj.ElevationPlot.YData = obj.Elevation;
            end

            % auto-recenter with ~10% margin
            latMin = min(obj.Latitude);
            latMax = max(obj.Latitude);
            lonMin = min(obj.Longitude);
            lonMax = max(obj.Longitude);

            dLat = (latMax - latMin) * 0.1;
            dLon = (lonMax - lonMin) * 0.1;

            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                geolimits(obj.Axes, [latMin-dLat, latMax+dLat], [lonMin-dLon, lonMax+dLon]);
            end

            if isempty(obj.TimeStamp)
                obj.StatsTable.Data = {};
            end

            obj.TotalTime = max(obj.TimeStamp);
            obj.AVGSpeed  = mean(obj.Speed, "omitnan");
            obj.STDSpeed  = std(obj.Speed, "omitnan");
            obj.ElevationGainLoss = sum(diff(obj.Elevation));

            obj.StatsTable.Data = {
                obj.TotalTime;
                obj.AVGSpeed;
                obj.STDSpeed;
                obj.ElevationGainLoss;
            };
        end

        % live chart & stats logic
        function setupLiveDisplays(obj, speedAxes, elevationAxes, statsTable)
            obj.SpeedAxes = speedAxes;
            obj.ElevationAxes = elevationAxes;
            obj.StatsTable = statsTable;

            % elevation plot
            if isempty(obj.ElevationPlot) || ~isvalid(obj.ElevationPlot)
                hold(obj.ElevationAxes, "on");
                obj.ElevationPlot = plot(obj.ElevationAxes, NaN, NaN, 'LineWidth', 2);
                title(obj.ElevationAxes, "Elevation vs Time");
                xlabel(obj.ElevationAxes, "Time (s)");
                ylabel(obj.ElevationAxes, "Elevation (m)");
            end
            
            % speed plot
            if isempty(obj.SpeedPlot) || ~isvalid(obj.SpeedPlot)
                hold(obj.SpeedAxes, "on");
                obj.SpeedPlot = plot(obj.SpeedAxes, NaN, NaN, 'LineWidth', 2);
                title(obj.SpeedAxes, "Speed vs Time");
                xlabel(obj.SpeedAxes, "Time (s)");
                ylabel(obj.SpeedAxes, "Speed (m/s)");
            end

            % stats
            obj.StatsTable.ColumnName = {'Value'};
            obj.StatsTable.RowName = {'Total Time (s)', 'Average Speed(m/s)', 'Standard Deviation Speed (m/s)', 'Elevation Gain/Loss (m)'};
            obj.StatsTable.Data = {};
        end

        function geoPlot(obj, Panel)

            if isempty(obj.GeoMapPlot) || ~isvalid(obj.GeoMapPlot)
                % Create 2D interactive geoaxes
                gx = geoaxes(Panel, 'Basemap', 'streets');  % or 'satellite', 'topographic', etc.
                obj.Axes = gx;
                obj.GeoMapPlot = geoplot(obj.Axes, NaN, NaN, 'r-', 'LineWidth', 2);
            end

        end

        function geoPlotLine(obj)

            start(obj.T);

            % set starting view
            if size(obj.Latitude) == 1
                geolimits(obj.Axes, ...
                [obj.Latitude(end)-0.005, obj.Latitude(end)+0.005], ...
                [obj.Longitude(end)-0.005, obj.Longitude(end)+0.005]);
            end     
        end
            
        function loadSavedWorkouts(obj)
            if isfile(obj.SaveFile)
                S = load(obj.SaveFile);
                obj.WorkoutNames = S.WorkoutNames;
                obj.WorkoutData  = S.WorkoutData;
            else
                obj.WorkoutNames = string.empty;
                obj.WorkoutData  = struct.empty;
            end
        end
        function saveWorkout(obj, workName, lat, lon, speed, elevation, t)

            workoutStruct = struct( ...
                'Name', workName, ...
                'Latitude', lat(:).', ...
                'Longitude', lon(:).', ...
                'Speed', speed(:).', ...
                'Elevation', elevation(:).', ...
                'TimeStamp', t(:).' ...
            );

            % Append new workout
            obj.WorkoutNames(end+1) = workName;
            obj.WorkoutData(end+1)  = workoutStruct;

            % Save permanently
            WorkNames = obj.WorkoutNames;
            WorkData  = obj.WorkoutData;
            save(obj.SaveFile, "WorkNames", "WorkData");
        end

        function workout = loadWorkout(obj, workoutName)
            idx = find(obj.WorkoutNames == workoutName, 1);
            if isempty(idx)
                workout = [];
            else
                workout = obj.WorkoutData(idx);
            end
        end

    end
end
