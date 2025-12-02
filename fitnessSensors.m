classdef fitnessSensors < handle
    properties
        AccelerationSignal; % Acceleration signal
        VelocitySignal; % Velocity Signal
        PositionSignal; % Latitude/Longitude Signal
        TargetSignalTs; % Time stamp Signal
    end
    properties(Access=private)
        mobileDevConnection;
    end
    
    methods
        function obj = fitnessSensors(accel, vel, pos, ts)
            
            % the phone connection
            obj.mobileDevConnection = mobiledev;

            % Log the mobile device connection

            if ~isempty(obj.mobileDevConnection)
                fprintf('Mobile device connection %s, is ready.\n',... 
                     obj.mobileDevConnection.Device);
            else
                error(['Mobile device connection failed. Ensure ' ...
                    'the MATLAB app is open on your phone...\n']);
            end

            obj.AccelerationSignal = accel;
            obj.VelocitySignal = vel;
            obj.PositionSignal = pos;
            obj.TargetSignalTs = ts;
        end
    end
end