function y=relay_block(u)
% Interpreted MATLAB Fcn adapter, input [t; 8 per-unit features].
% Call clear relay_block before every simulation. Normal simulation only.
persistent M state lastTime lastOutput
if isempty(M)
    d=load('trained_dual_ann.mat','M'); M=d.M; state=[]; lastTime=-inf;
    lastOutput=[0;0;0;0;0];
end
u=u(:); t=u(1);
if t<lastTime, state=[]; lastTime=-inf; end
if abs(t-lastTime)<M.c.featureStep/2
    y=lastOutput; return
end
P=predict_dual_ann(M,u(2:9));
p.fault=P.fault; p.classId=P.classId; p.distanceKm=P.distanceKm;
[o,state]=relay_logic(p,t,state,M.c);
d=o.distanceKm; if ~o.locationValid, d=0; end
y=[double(o.trip);o.classId;d;double(o.locationValid);P.score];
lastTime=t; lastOutput=y;
end
