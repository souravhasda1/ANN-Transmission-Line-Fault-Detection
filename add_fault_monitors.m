function add_fault_monitors()
% Run once from the project folder in MATLAB R2024a.
% Creates a separate electrical model with live waveform/RMS scopes.
% The original model and ANN training files are not changed.
if exist('ann_transmission_line_manual.slx','file')
    src='ann_transmission_line_manual';
else
    src='ann_transmission_line';
end
dst='ann_line_with_monitors';
assert(exist([src '.slx'],'file')==2,'Open the project folder in MATLAB first.');
assert(exist([dst '.slx'],'file')~=2, ...
    '%s.slx already exists. Open that model instead of rebuilding.',dst);
load_system(src);
save_system(src,dst);
load_system(dst);
load_system('spsRMSLib');
r=find_system('spsRMSLib','SearchDepth',1,'Name','RMS');
assert(numel(r)==1,'Could not find the R2024a SPS RMS block.');
rmsPath=r{1};
v=get_param([dst '/Measure'],'PortHandles');
assert(numel(v.Outport)>=2,'Measure must output Vabc and Iabc.');

% Each three-phase vector gives three traces on its Scope.
scope('Vabc waveform',[1080 100 1210 145]);
scope('Iabc waveform',[1080 185 1210 230]);
connect(v.Outport(1),'Vabc waveform',1);
connect(v.Outport(2),'Iabc waveform',1);

% Separate each phase for scalar RMS blocks.
add_block('simulink/Signal Routing/Demux',[dst '/Split Vabc'], ...
    'Outputs','3','Position',[170 535 175 655]);
add_block('simulink/Signal Routing/Demux',[dst '/Split Iabc'], ...
    'Outputs','3','Position',[170 705 175 825]);
connect(v.Outport(1),'Split Vabc',1);
connect(v.Outport(2),'Split Iabc',1);
vp=get_param([dst '/Split Vabc'],'PortHandles');
ip=get_param([dst '/Split Iabc'],'PortHandles');

% V0=(Va+Vb+Vc)/3 and I0=(Ia+Ib+Ic)/3, instantaneous.
add_block('simulink/Math Operations/Sum',[dst '/V phase sum'], ...
    'Inputs','+++','Position',[255 850 280 925]);
add_block('simulink/Math Operations/Sum',[dst '/I phase sum'], ...
    'Inputs','+++','Position',[255 965 280 1040]);
for k=1:3
    connect(vp.Outport(k),'V phase sum',k);
    connect(ip.Outport(k),'I phase sum',k);
end
add_block('simulink/Math Operations/Gain',[dst '/V0 divide by 3'], ...
    'Gain','1/3','Position',[325 870 390 910]);
add_block('simulink/Math Operations/Gain',[dst '/I0 divide by 3'], ...
    'Gain','1/3','Position',[325 985 390 1025]);
lineBetween('V phase sum','V0 divide by 3');
lineBetween('I phase sum','I0 divide by 3');
scope('V0 waveform',[1080 270 1210 315]);
scope('I0 waveform',[1080 355 1210 400]);
lineBetween('V0 divide by 3','V0 waveform');
lineBetween('I0 divide by 3','I0 waveform');

% One-cycle total RMS at 50 Hz. Keep the electrical step at 50 microseconds.
for k=1:4
    y=535+75*(k-1);
    add_block(rmsPath,[dst sprintf('/V RMS %d',k)], ...
        'TrueRMS','on','Freq','50','Ts','50e-6','RMSInit','0', ...
        'Position',[470 y 540 y+40]);
    add_block(rmsPath,[dst sprintf('/I RMS %d',k)], ...
        'TrueRMS','on','Freq','50','Ts','50e-6','RMSInit','0', ...
        'Position',[650 y 720 y+40]);
    if k<=3
        connect(vp.Outport(k),sprintf('V RMS %d',k),1);
        connect(ip.Outport(k),sprintf('I RMS %d',k),1);
    else
        lineBetween('V0 divide by 3',sprintf('V RMS %d',k));
        lineBetween('I0 divide by 3',sprintf('I RMS %d',k));
    end
end
add_block('simulink/Signal Routing/Mux',[dst '/V RMS vector'], ...
    'Inputs','4','Position',[825 570 830 810]);
add_block('simulink/Signal Routing/Mux',[dst '/I RMS vector'], ...
    'Inputs','4','Position',[945 570 950 810]);
for k=1:4
    connect(get_param([dst sprintf('/V RMS %d',k)],'PortHandles').Outport(1),'V RMS vector',k);
    connect(get_param([dst sprintf('/I RMS %d',k)],'PortHandles').Outport(1),'I RMS vector',k);
end
scope('Voltage RMS Va Vb Vc V0',[1080 440 1260 485]);
scope('Current RMS Ia Ib Ic I0',[1080 525 1260 570]);
lineBetween('V RMS vector','Voltage RMS Va Vb Vc V0');
lineBetween('I RMS vector','Current RMS Ia Ib Ic I0');
add_block('simulink/Sinks/Display',[dst '/V RMS numbers'], ...
    'Position',[1080 640 1235 720]);
add_block('simulink/Sinks/Display',[dst '/I RMS numbers'], ...
    'Position',[1080 760 1235 840]);
lineBetween('V RMS vector','V RMS numbers');
lineBetween('I RMS vector','I RMS numbers');

save_system(dst);
open_system(dst);
fprintf('Saved %s.slx. Run it, then open the six Scopes.\n',dst);
fprintf('RMS vectors are [A B C zero-sequence]. The first 20 ms is startup.\n');
fprintf('This electrical model does not contain live ANN inference.\n');

    function scope(name,pos)
        add_block('simulink/Sinks/Scope',[dst '/' name],'Position',pos);
    end
    function connect(port,block,number)
        ph=get_param([dst '/' block],'PortHandles');
        add_line(dst,port,ph.Inport(number),'autorouting','on');
    end
    function lineBetween(a,b)
        ph=get_param([dst '/' a],'PortHandles');
        connect(ph.Outport(1),b,1);
    end
end
