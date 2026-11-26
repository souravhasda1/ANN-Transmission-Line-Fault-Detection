function build_relay_demo(M,raw)
% Executable Simulink inference demo with precomputed CAUSAL feature playback.
% This is not closed-loop breaker control. The guide explains the live wiring.
[X,t]=extract_features(raw,M.c);
assignin('base','relayFeatures',timeseries(X',t'));
clear relay_block
m='ann_relay_replay';
if bdIsLoaded(m), close_system(m,0); end
if exist([m '.slx'],'file')
    error('%s.slx already exists; open it and update relayFeatures instead.',m);
end
new_system(m);
set_param(m,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',num2str(M.c.featureStep),'StopTime',num2str(t(end)), ...
    'ReturnWorkspaceOutputs','on','InitFcn','clear relay_block');
add_block('simulink/Sources/From Workspace',[m '/Features'], ...
    'VariableName','relayFeatures','Interpolate','off', ...
    'SampleTime',num2str(M.c.featureStep),'Position',[50 125 180 165]);
add_block('simulink/Sources/Digital Clock',[m '/Clock'], ...
    'SampleTime',num2str(M.c.featureStep),'Position',[70 45 130 75]);
add_block('simulink/Signal Routing/Mux',[m '/Mux'],'Inputs','2', ...
    'Position',[235 50 240 160]);
load_system('simulink');
matches = find_system('simulink','SearchDepth',2,'BlockType','MATLABFcn');
matches = matches(contains(string(matches),'Interpreted MATLAB'));
assert(numel(matches)==1,'Could not find the Interpreted MATLAB Function block.');
add_block(matches{1},[m '/Relay'], ...
    'MATLABFcn','relay_block(u)','OutputDimensions','5','Position',[300 80 450 130]);
add_block('simulink/Sinks/To Workspace',[m '/Results'], ...
    'VariableName','relayOutputs','SaveFormat','Timeseries','Position',[520 80 660 130]);
add_line(m,'Clock/1','Mux/1'); add_line(m,'Features/1','Mux/2');
add_line(m,'Mux/1','Relay/1'); add_line(m,'Relay/1','Results/1');
save_system(m); open_system(m);
fprintf('Run %s. Outputs: trip, class ID, distance km, location-valid, score.\n',m);
end
