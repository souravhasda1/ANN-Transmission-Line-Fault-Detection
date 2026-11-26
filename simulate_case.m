function raw=simulate_case(s,c)
% s is one row of make_scenarios output. Outputs SI units (V and A).
if nargin<2, c=project_config(); end
assert(height(s)==1 && s.distanceKm>0 && s.distanceKm<c.lineKm);
m=c.model; load_system(m);
in=Simulink.SimulationInput(m);
in=in.setBlockParameter([m '/Line1'],'Length',num2str(s.distanceKm,17));
in=in.setBlockParameter([m '/Line2'],'Length',num2str(c.lineKm-s.distanceKm,17));
Z=c.VLL^2/s.Ssc; R=Z/sqrt(1+c.XR^2); L=c.XR*R/(2*pi*c.f0);
in=in.setBlockParameter([m '/Source'],'Resistance',num2str(R,17));
in=in.setBlockParameter([m '/Source'],'Inductance',num2str(L,17));
in=in.setBlockParameter([m '/Source'],'PhaseAngle',num2str(s.sourcePhase,17));
in=in.setBlockParameter([m '/Load'],'ActivePower',num2str(c.loadP*s.loadScale,17));
in=in.setBlockParameter([m '/Load'],'InductivePower',num2str(c.loadQ*s.loadScale,17));
bits=c.bits(s.classId,:);
if s.classId==1
    % Keep a valid fault selection, but schedule it outside the simulation.
    bits=[1 0 0 1]; times=[1 2];
else
    times=[s.tOn s.tOff];
end
names={'FaultA','FaultB','FaultC','GroundFault'};
for j=1:4
    val='off'; if bits(j), val='on'; end
    in=in.setBlockParameter([m '/Fault'],names{j},val);
end
in=in.setBlockParameter([m '/Fault'],'SwitchTimes',mat2str(times,17));
in=in.setBlockParameter([m '/Fault'],'FaultResistance',num2str(s.Rf,17));
in=in.setBlockParameter([m '/Fault'],'GroundResistance',num2str(s.Rg,17));
in=in.setModelParameter('StopTime',num2str(c.stopTime),'ReturnWorkspaceOutputs','on');
out=sim(in);
v=out.get('Vabc'); i=out.get('Iabc');
raw.t=double(v.Time(:)); raw.V=double(squeeze(v.Data)); raw.I=double(squeeze(i.Data));
assert(size(raw.V,2)==3 && size(raw.I,2)==3,'Expected N-by-3 measurements.');
assert(isequal(v.Time,i.Time),'Voltage and current clocks differ.');
assert(all(isfinite(raw.V(:))) && all(isfinite(raw.I(:))),'Nonfinite waveforms.');
raw.scenario=s;
end
