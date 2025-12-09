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
        DateAndTime;

        WorkoutNames (1,:) string;        % Names shown in dropdown
        WorkoutData = struct( ...
            'Latitude', {}, ...
            'Longitude', {}, ...
            'TimeStamp', {}, ...
            'Speed', {}, ...
            'Elevation', {}, ...
            'Stats', {} );  % Struct array for each workout
        WorkoutFile = "workoutHistory.mat"  % Where permanent data is stored

        AchievementFile = 'AllAchievements.mat'

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
                fprintf("Starting workout for %d hours, %d minutes," + ...
                    " and %d seconds...\n", hours, minutes, seconds);
            else
                fprintf("Starting workout with no time limit...\n");
            end
            
            obj.mobileDevConnection.Logging = 1;

            obj.DateAndTime = datetime('now');

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

        function unpause(obj)

            if obj.IsWorkoutActive && obj.IsPaused

                % Restart the timer
                start(obj.T);

            obj.mobileDevConnection.Logging = 1;
            obj.IsPaused = false;
            fprintf("Workout resumed.\n");
            end
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

            % Stop & delete timers
            if ~isempty(obj.T) && isvalid(obj.T)
                stop(obj.T);
                delete(obj.T);
            end

            obj.T = [];

            if isprop(obj, "StopTimer") && ~isempty(obj.StopTimer) && ...
                    isvalid(obj.StopTimer)
                
                stop(obj.StopTimer);
                delete(obj.StopTimer);
            end

            obj.StopTimer = [];

            % Reset latest values
            obj.TimeStamp = [];
            obj.Speed = [];
            obj.Elevation = [];
            obj.Latitude = [];
            obj.Longitude = [];
            obj.AVGSpeed = [];
            obj.STDSpeed = [];
            obj.ElevationGainLoss = [];
            obj.TotalTime = [];

            % Reset stats
            if ~isempty(obj.StatsTable)
                obj.StatsTable.Data = {};
            end

            % Reset plots data
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
        
        % timer callback
        function timerUpdatePos(obj)

            % Make sure timer is still valid

            if ~obj.IsWorkoutActive || obj.IsPaused
                return;
            end
            
            [lat, lon, timestamp, speed, ~, alt, ~] = ...
                poslog(obj.mobileDevConnection);

            if isempty(lat)
                return;
            end

            obj.TimeStamp = timestamp(:).';
            obj.Speed = speed(:).';
            obj.Elevation = alt(:).';

            % append to route
            obj.Latitude = lat(:).';
            obj.Longitude = lon(:).';

            % update line data
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
                geolimits(obj.Axes, [latMin-dLat, latMax+dLat], ...
                    [lonMin-dLon, lonMax+dLon]);
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
        function setupLiveDisplays(obj, speedAxes, elevationAxes, ...
                statsTable)
            obj.SpeedAxes = speedAxes;
            obj.ElevationAxes = elevationAxes;
            obj.StatsTable = statsTable;

            % elevation plot
            if isempty(obj.ElevationPlot) || ~isvalid(obj.ElevationPlot)
                hold(obj.ElevationAxes, "on");
                obj.ElevationPlot = plot(obj.ElevationAxes, NaN, NaN, ...
                    'LineWidth', 2);
                title(obj.ElevationAxes, "Elevation vs Time");
                xlabel(obj.ElevationAxes, "Time (s)");
                ylabel(obj.ElevationAxes, "Elevation (m)");
            end
            
            % speed plot
            if isempty(obj.SpeedPlot) || ~isvalid(obj.SpeedPlot)
                hold(obj.SpeedAxes, "on");
                obj.SpeedPlot = plot(obj.SpeedAxes, NaN, NaN, ...
                    'LineWidth', 2);
                title(obj.SpeedAxes, "Speed vs Time");
                xlabel(obj.SpeedAxes, "Time (s)");
                ylabel(obj.SpeedAxes, "Speed (m/s)");
            end

            % stats
            obj.StatsTable.ColumnName = {'Value'};
            obj.StatsTable.RowName = {'Total Time (s)', ['Average ' ...
                'Speed(m/s)'], 'Standard Deviation Speed (m/s)', ...
                'Elevation Gain/Loss (m)'};
            obj.StatsTable.Data = {};
        end

        function geoPlot(obj, Panel)

            if isempty(obj.GeoMapPlot) || ~isvalid(obj.GeoMapPlot)
                % Create 2D interactive geoaxes
                gx = geoaxes(Panel, 'Basemap', 'streets'); 
                obj.Axes = gx;
                obj.GeoMapPlot = geoplot(obj.Axes, NaN, NaN, 'r-', ... 
                    'LineWidth', 2);
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

            if isfile(obj.WorkoutFile)
                S = load(obj.WorkoutFile);
                if isfield(S,"WorkNames") && isfield(S,"WorkData")
                    obj.WorkoutNames = S.WorkNames;
                    obj.WorkoutData  = S.WorkData;
                else
                    obj.WorkoutNames = string.empty;
                    obj.WorkoutData = struct( ...
                        'Latitude', {}, ...
                        'Longitude', {}, ...
                        'TimeStamp', {}, ...
                        'Speed', {}, ...
                        'Elevation', {}, ...
                        'Stats', {} );

                end
            end
        end

        function saveWorkout(obj)

            workoutStruct = struct( ...
                'Latitude',  obj.Latitude, ...
                'Longitude', obj.Longitude, ...
                'TimeStamp', obj.TimeStamp, ...
                'Speed',     obj.Speed, ...
                'Elevation', obj.Elevation, ...
                'Stats', struct( ...
                    'TotalTime', obj.TotalTime, ...
                    'AVGSpeed',  obj.AVGSpeed, ...
                    'STDSpeed',  obj.STDSpeed, ...
                    'ElevationGainLoss', obj.ElevationGainLoss) ...
            );

            % Store
            obj.WorkoutNames(end+1) = string(obj.DateAndTime);
            obj.WorkoutData(end+1)  = workoutStruct;

            % Save to file
            WorkNames = obj.WorkoutNames;
            WorkData  = obj.WorkoutData;
            save(obj.WorkoutFile,"WorkNames","WorkData")
        end

        function loadWorkout(obj, workoutName)

            % Find workout
            idx = find(obj.WorkoutNames == workoutName, 1);
            
            if isempty(idx)
                warning("Workout not found.");
                return;
            end

            % Fetch stored struct
            W = obj.WorkoutData(idx);

            % Restore data into object
            obj.Latitude  = W.Latitude;
            obj.Longitude = W.Longitude;
            obj.TimeStamp = W.TimeStamp;
            obj.Speed     = W.Speed;
            obj.Elevation = W.Elevation;

            % Restore stats
            obj.TotalTime          = W.Stats.TotalTime;
            obj.AVGSpeed           = W.Stats.AVGSpeed;
            obj.STDSpeed           = W.Stats.STDSpeed;
            obj.ElevationGainLoss  = W.Stats.ElevationGainLoss;

            % 4. Update plots
            if ~isempty(obj.SpeedPlot) && isvalid(obj.SpeedPlot)
                obj.SpeedPlot.XData = obj.TimeStamp;
                obj.SpeedPlot.YData = obj.Speed;
            end

            if ~isempty(obj.ElevationPlot) && isvalid(obj.ElevationPlot)
                obj.ElevationPlot.XData = obj.TimeStamp;
                obj.ElevationPlot.YData = obj.Elevation;
            end

            % Update geo map
            if ~isempty(obj.GeoMapPlot) && isvalid(obj.GeoMapPlot)
                obj.GeoMapPlot.LatitudeData  = obj.Latitude;
                obj.GeoMapPlot.LongitudeData = obj.Longitude;

                latMin = min(obj.Latitude); latMax = max(obj.Latitude);
                lonMin = min(obj.Longitude); lonMax = max(obj.Longitude);
                geolimits(obj.Axes, [latMin latMax], [lonMin lonMax]);
            end

            % Update stats table
            if ~isempty(obj.StatsTable)
                obj.StatsTable.Data = {
                    obj.TotalTime;
                    obj.AVGSpeed;
                    obj.STDSpeed;
                    obj.ElevationGainLoss;
                };
            end

            fprintf("Workout '%s' loaded.\n", workoutName);

        end

        function d = haversineDistance(~, lat1, lon1, lat2, lon2)
            R = 6371000; % Earth's radius in meters
            lat1 = deg2rad(lat1);
            lon1 = deg2rad(lon1);
            lat2 = deg2rad(lat2);
            lon2 = deg2rad(lon2);

            dlat = lat2 - lat1;
            dlon = lon2 - lon1;

            a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
            c = 2 * atan2(sqrt(a), sqrt(1 - a));

            d = R * c; % distance in meters
        end


        function achievements = getAchievements(obj)

            fastestRun = struct('Date', [], 'Speed', []);
            longestDistance = struct('Date', [], 'Distance', []);
            highestGain = struct('Date', [], 'Gain', []);
            longestDuration = struct('Date', [], 'Duration', []);
            
            achievements = struct( ...
                'FastestRun', fastestRun, ...
                'LongestDistance', longestDistance, ...
                'HighestElevationGain', highestGain, ...
                'LongestDuration', longestDuration);

            for i = 1:numel(obj.WorkoutNames)
                W = obj.WorkoutData(i);

                maxSpeed = max(W.Speed, [], "omitnan");

                lat = W.Latitude;
                lon = W.Longitude;
                
                totalDist = 0;
                if numel(lat) >= 1
                    for k = 1:numel(lat)-1
                        totalDist = totalDist + obj.haversineDistance(...
                            lat(k), lon(k), lat(k+1), lon(k+1) );
                    end
                end

                elevGain = sum(diff(W.Elevation), "omitnan");

                duration = W.TimeStamp(end);

                if isempty(achievements.FastestRun.Speed) || maxSpeed > achievements.FastestRun.Speed
                    fastestRun = struct('Date', obj.WorkoutNames(i), ...
                        'Speed', maxSpeed);
                end

                % Longest Distance
                if isempty(achievements.LongestDistance.Distance) || totalDist > achievements.LongestDistance.Distance
                    longestDistance = struct('Date', obj.WorkoutNames(i), ...
                        'Distance', totalDist);
                end

                % Highest Elevation Gain
                if isempty(achievements.HighestElevationGain.Gain) || elevGain > achievements.HighestElevationGain.Gain
                    highestGain = struct('Date', obj.WorkoutNames(i), ...
                        'Gain', elevGain);
                end

                % Longest Duration
                if isempty(achievements.LongestDuration.Duration) || duration > achievements.LongestDuration.Duration
                    longestDuration = struct('Date', obj.WorkoutNames(i), ...
                        'Duration', duration);
                end
            end

            achievements = struct('FastestRun', fastestRun, ...
                    'LongestDistance', longestDistance, ...
                    'HighestElevationGain', highestGain, ...
                    'LongestDuration', longestDuration);

        end
        
    end
end
