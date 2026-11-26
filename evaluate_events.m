function E=evaluate_events(M,folder,toleranceKm)
% Held-out event metrics. Future persistence here is an EVALUATION criterion.
% It does not change the causal relay algorithm.
if nargin<3, toleranceKm=0.5; end
ids=M.split.testGroups; n=numel(ids);
classId=zeros(n,1); falseTrip=false(n,1); missed=false(n,1);
delayMs=NaN(n,1); classSettleMs=NaN(n,1); locationSettleMs=NaN(n,1);
holdN=round(1/M.c.f0/M.c.featureStep); % must remain correct for one cycle
for j=1:n
    a=load(fullfile(folder,sprintf('case_%05d.mat',ids(j))),'raw');
    raw=a.raw; s=raw.scenario; classId(j)=s.classId;
    R=replay_case(M,raw,false); falseTrip(j)=R.preFaultFalseTrip;
    if s.classId==1, continue; end
    after=R.t>=s.tOn;
    missed(j)=~any(R.trip(after)); delayMs(j)=R.detectionDelayMs;
    goodClass=(R.classId==s.classId)&after;
    goodLocation=R.locationValid & abs(R.distanceKm-s.distanceKm)<=toleranceKm & after;
    classSettleMs(j)=settle(goodClass,R.t,s.tOn,holdN);
    locationSettleMs(j)=settle(goodLocation,R.t,s.tOn,holdN);
end
E=table(ids(:),classId,falseTrip,missed,delayMs,classSettleMs,locationSettleMs, ...
    'VariableNames',{'scenarioId','trueClassId','falseTripBeforeFault', ...
    'missedFault','detectionDelayMs','classSettleMs','locationSettleMs'});
writetable(E,'heldout_event_results.csv'); disp(E);
end
function delay=settle(good,t,tOn,n)
delay=NaN;
for k=1:numel(good)-n+1
    if all(good(k:k+n-1)), delay=1000*(t(k)-tOn); return; end
end
end
