function [o,state]=relay_logic(p,t,state,c)
% Deterministic relay logic at exactly c.featureStep. Trip is latched.
% This is an educational fault flag, not validated zone-selective protection.
if isempty(state)
    state.count=0; state.classCount=0; state.lastClass=-1;
    state.trip=false; state.locationBuffer=[];
end
o.trip=state.trip; o.classId=0; o.distanceKm=NaN; o.locationValid=false;
if t<c.blankTime
    state.count=0; state.classCount=0; state.locationBuffer=[]; return
end
if p.fault
    state.count=state.count+1;
else
    state.count=0; state.classCount=0; state.lastClass=-1;
    state.locationBuffer=[];
end
active=state.count>=c.confirmSamples;
if active, state.trip=true; end
o.trip=state.trip; % remains true until explicit reset/new simulation
if ~active
    if ~p.fault, o.classId=1; end
    return
end
if p.classId==state.lastClass
    state.classCount=state.classCount+1;
else
    state.lastClass=p.classId; state.classCount=1;
    state.locationBuffer=[];
end
if state.classCount>=c.classConfirmSamples && p.classId>=2
    o.classId=p.classId;
    state.locationBuffer=[state.locationBuffer p.distanceKm];
    state.locationBuffer=state.locationBuffer(max(1,end-4):end);
    o.distanceKm=median(state.locationBuffer);
    o.locationValid=true;
end
end
