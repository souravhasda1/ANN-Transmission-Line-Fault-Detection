function add_live_ann_to_scope_model()
% Adds ANN trip/class/location displays to ann_fresh_fault_scopes.slx.
% Requires trained_dual_ann.mat and the other project .m files on path.
m='ann_fresh_fault_scopes';
assert(isfile([m '.slx']), 'Build ann_fresh_fault_scopes.slx first.');
assert(exist('trained_dual_ann.mat','file')==2, ...
    'Copy trained_dual_ann.mat into the MATLAB Current Folder first.');
needed={'electrical_relay_live','live_rms_features','relay_block', ...
        'predict_dual_ann','relay_logic','decode_fault'};
for k=1:numel(needed)
    assert(exist(needed{k},'file')==2,'Cannot find %s.m on MATLAB path.',needed{k});
end
load_system(m);
assert(getSimulinkBlockHandle([m '/Live ANN'])==-1, ...
    'Live ANN already exists. Open the model and run it.');
assert(abs(str2double(get_param(m,'FixedStep'))-50e-6)<1e-12, ...
    'This adapter requires a 50-us fixed electrical step.');
assert(str2double(get_param([m '/Source'],'Voltage'))==11000 && ...
       str2double(get_param([m '/Source'],'Frequency'))==50, ...
    'This trained-feature adapter assumes an 11-kV, 50-Hz electrical model.');

% Keep a recoverable copy of the current electrical model.
save_system(m);
backup=[m '_before_live_ann.slx'];
if ~exist(backup,'file'), copyfile([m '.slx'],backup); end

load_system('simulink');
b=find_system('simulink','SearchDepth',2,'BlockType','MATLABFcn');
b=b(contains(string(b),'Interpreted MATLAB'));
assert(numel(b)==1,'Interpreted MATLAB Function block is missing.');

add_block('simulink/Sources/Digital Clock',[m '/ANN clock'], ...
    'SampleTime','50e-6','Position',[1300 80 1380 115]);
add_block('simulink/Signal Routing/Mux',[m '/ANN inputs'], ...
    'Inputs','3','Position',[1450 100 1455 230]);
add_block(b{1},[m '/Live ANN'],'MATLABFcn','electrical_relay_live(u)', ...
    'OutputDimensions','5','Position',[1535 130 1680 200]);
add_block('simulink/Signal Routing/Demux',[m '/ANN outputs'], ...
    'Outputs','5','Position',[1750 90 1755 315]);

measure=get_param([m '/Measure'],'PortHandles');
clock=get_param([m '/ANN clock'],'PortHandles');
inputs=get_param([m '/ANN inputs'],'PortHandles');
add_line(m,clock.Outport(1),inputs.Inport(1),'autorouting','on');
add_line(m,measure.Outport(1),inputs.Inport(2),'autorouting','on');
add_line(m,measure.Outport(2),inputs.Inport(3),'autorouting','on');
wire('ANN inputs','Live ANN'); wire('Live ANN','ANN outputs');
ports=get_param([m '/ANN outputs'],'PortHandles');
names={'Trip 0 or 1','Class ID','Estimated distance km', ...
       'Location valid 0 or 1','Fault score'};
for k=1:5
    y=65+90*k;
    add_block('simulink/Sinks/Display',[m '/' names{k}], ...
        'Position',[1890 y 2050 y+55]);
    to=get_param([m '/' names{k}],'PortHandles');
    add_line(m,ports.Outport(k),to.Inport(1),'autorouting','on');
end
add_block('simulink/Sinks/Scope',[m '/Trip scope'], ...
    'Position',[2140 150 2270 200]);
add_block('simulink/Sinks/Scope',[m '/Distance scope'], ...
    'Position',[2140 330 2270 380]);
trip=get_param([m '/Trip scope'],'PortHandles');
add_line(m,ports.Outport(1),trip.Inport(1),'autorouting','on');

% Compare predicted location to the junction's location, Line1 length.
trueDistance=['str2double(get_param(''' m '/Line1'',''Length''))'];
add_block('simulink/Sources/Constant',[m '/True distance km'], ...
    'Value',trueDistance,'Position',[1880 710 2050 745]);
add_block('simulink/Sinks/Display',[m '/True distance display'], ...
    'Position',[2130 700 2280 750]);
add_block('simulink/Signal Routing/Mux',[m '/Compare distance'], ...
    'Inputs','2','Position',[2085 345 2090 420]);
truth=get_param([m '/True distance km'],'PortHandles');
truthDisplay=get_param([m '/True distance display'],'PortHandles');
compare=get_param([m '/Compare distance'],'PortHandles');
add_line(m,truth.Outport(1),truthDisplay.Inport(1),'autorouting','on');
add_line(m,ports.Outport(3),compare.Inport(1),'autorouting','on');
add_line(m,truth.Outport(1),compare.Inport(2),'autorouting','on');
wire('Compare distance','Distance scope');
add_block('simulink/Sinks/To Workspace',[m '/ANN results'], ...
    'VariableName','liveAnnOutputs','SaveFormat','Timeseries', ...
    'Position',[2140 460 2280 510]);
wire('Live ANN','ANN results');

% Reset MATLAB persistent states at the start of every simulation.
set_param(m,'InitFcn', ...
    'clear electrical_relay_live live_rms_features relay_block');
save_system(m);
open_system(m);
fprintf('Added live ANN monitors to %s.slx. Use Normal simulation mode.\n',m);
fprintf('Distance scope: first trace predicted, second trace true Line1 km.\n');
fprintf('Read predicted distance only when Location valid = 1.\n');

    function wire(from,to)
        f=get_param([m '/' from],'PortHandles');
        q=get_param([m '/' to],'PortHandles');
        add_line(m,f.Outport(1),q.Inport(1),'autorouting','on');
    end
end
