function build_power_model(c)
% Creates an SPS model using library names inspected in R2024a.
% Requires Simulink + Simscape Electrical (Specialized Power Systems).
if nargin==0, c=project_config(); end
m=c.model;
if bdIsLoaded(m), error('Close %s before building; unsaved work is protected.',m); end
if exist([m '.slx'],'file'), error('%s.slx already exists. Use it or rename it.',m); end
new_system(m);
set_param(m,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',num2str(c.Ts,17),'StopTime',num2str(c.stopTime), ...
    'ReturnWorkspaceOutputs','on');
put('spspowerguiLib','powergui',[35 30 130 70]);
set_param([m '/powergui'],'SimulationMode','Discrete','SampleTime',num2str(c.Ts,17));
put('spsThreePhaseSourceLib','Source',[35 170 115 255]);
set_param([m '/Source'],'InternalConnection','Yg','Voltage',num2str(c.VLL), ...
    'Frequency',num2str(c.f0),'PhaseAngle','0','NonIdealSource','on', ...
    'SpecifyImpedance','off');
Z=c.VLL^2/c.Ssc; R=Z/sqrt(1+c.XR^2); L=c.XR*R/(2*pi*c.f0);
set_param([m '/Source'],'Resistance',num2str(R,17),'Inductance',num2str(L,17));
put('spsThreePhaseVIMeasurementLib','Measure',[170 170 220 255]);
set_param([m '/Measure'],'VoltageMeasurement','phase-to-ground', ...
    'CurrentMeasurement','yes','Vpu','off','Ipu','off');
put('spsThreePhasePISectionLineLib','Line1',[295 170 400 255]);
put('spsThreePhasePISectionLineLib','Line2',[485 170 590 255]);
for name={'Line1','Line2'}
    set_param([m '/' name{1}],'Frequency',num2str(c.f0), ...
        'Resistances',mat2str(c.r,17),'Inductances',mat2str(c.l,17), ...
        'Capacitances',mat2str(c.cap,17),'Length','5');
end
put('spsThreePhaseFaultLib','Fault',[410 340 465 425]);
set_param([m '/Fault'],'InitialStates','0','External','off', ...
    'FaultA','on','FaultB','off','FaultC','off','GroundFault','on', ...
    'SwitchTimes','[0.1 0.3]','FaultResistance','0.1','GroundResistance','0.1', ...
    'SnubberResistance','1e6','SnubberCapacitance','inf');
put('spsThreePhaseTransformerTwoWindingsLib','Transformer',[665 165 760 260]);
set_param([m '/Transformer'],'UNITS','pu','NominalPower','[1e6 50]', ...
    'Winding1Connection','Yg','Winding2Connection','Yg', ...
    'Winding1','[11000 0.005 0.025]','Winding2','[400 0.005 0.025]', ...
    'Rm','500','Lm','500','SetSaturation','off');
put('spsThreePhaseParallelRLCLoadLib','Load',[830 170 900 255]);
set_param([m '/Load'],'Configuration','Y (grounded)','NominalVoltage','400', ...
    'NominalFrequency','50','ActivePower',num2str(c.loadP), ...
    'InductivePower',num2str(c.loadQ),'CapacitivePower','0');
connect3('Source','out','Measure','in');
connect3('Measure','out','Line1','in');
connect3('Line1','out','Line2','in');
connect3('Line1','out','Fault','all');
connect3('Line2','out','Transformer','in');
connect3('Transformer','out','Load','all');
for q=1:2
    names={'Vabc','Iabc'}; nm=names{q};
    add_block('simulink/Sinks/To Workspace',[m '/' nm], ...
        'Position',[270 25+55*q 370 50+55*q], ...
        'VariableName',nm,'SaveFormat','Timeseries','MaxDataPoints','inf','Decimation','1');
    ph=get_param([m '/Measure'],'PortHandles');
    th=get_param([m '/' nm],'PortHandles');
    add_line(m,ph.Outport(q),th.Inport(1),'autorouting','on');
end
save_system(m); open_system(m);
fprintf('Created %s.slx. Inspect phase order and run smoke_test next.\n',m);

    function put(lib,name,pos)
        load_system(lib);
        list=find_system(lib,'SearchDepth',1,'Type','Block');
        assert(numel(list)==1,'Unexpected library layout: %s',lib);
        add_block(list{1},[m '/' name],'Position',pos);
    end
    function p=ports(name,side)
        h=get_param([m '/' name],'PortHandles');
        switch side
            case 'in', p=h.LConn;
            case 'out', p=h.RConn;
            otherwise, p=[h.LConn h.RConn];
        end
        % Source/Fault/Load may expose the terminals on either icon side.
        if isempty(p), p=[h.LConn h.RConn]; end
        assert(numel(p)==3,'Expected 3 phase ports on %s; inspect block.',name);
    end
    function connect3(a,sa,b,sb)
        pa=ports(a,sa); pb=ports(b,sb);
        for k=1:3, add_line(m,pa(k),pb(k),'autorouting','on'); end
    end
end
