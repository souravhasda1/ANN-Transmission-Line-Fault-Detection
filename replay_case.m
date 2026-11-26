function R=replay_case(M,raw,makePlot)
% Causal replay. Features never use future waveform samples.
if nargin<3, makePlot=true; end
[X,t,valid]=extract_features(raw,M.c); P=predict_dual_ann(M,X);
R.t=t; R.score=P.score; R.trip=false(size(t)); R.classId=zeros(size(t));
R.distanceKm=NaN(size(t)); R.locationValid=false(size(t)); state=[];
for k=1:numel(t)
    p.fault=P.fault(k)&&valid(k); p.classId=P.classId(k); p.distanceKm=P.distanceKm(k);
    [o,state]=relay_logic(p,t(k),state,M.c);
    R.trip(k)=o.trip; R.classId(k)=o.classId;
    R.distanceKm(k)=o.distanceKm; R.locationValid(k)=o.locationValid;
end
s=raw.scenario;
if s.classId>1
    R.preFaultFalseTrip=any(R.trip(t<s.tOn));
    k=find(R.trip & t>=s.tOn,1);
    R.detectionDelayMs=NaN;
    if ~R.preFaultFalseTrip && ~isempty(k), R.detectionDelayMs=1000*(t(k)-s.tOn); end
else
    R.preFaultFalseTrip=any(R.trip); R.detectionDelayMs=NaN;
end
if makePlot
    figure('Name','Causal relay replay');
    subplot(4,1,1); plot(raw.t,raw.I); ylabel('Current (A)'); grid on;
    legend('Ia','Ib','Ic');
    subplot(4,1,2); plot(t,R.score); hold on; yline(M.c.detectorThreshold,'--');
    stairs(t,double(R.trip)); ylabel('Score / trip'); grid on;
    subplot(4,1,3); stairs(t,R.classId); ylabel('Class ID'); grid on; ylim([0 13]);
    subplot(4,1,4); plot(t,R.distanceKm); hold on;
    if s.classId>1, yline(s.distanceKm,'--'); end
    ylabel('Distance (km)'); xlabel('Time (s)'); grid on;
end
fprintf('Scenario %d: false pre-fault trip %d, delay %.2f ms\n', ...
    s.id,R.preFaultFalseTrip,R.detectionDelayMs);
end
