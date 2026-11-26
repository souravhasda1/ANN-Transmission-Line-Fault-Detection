function S=make_scenarios(nPerClass,c,seed)
% Independent electrical scenarios. No repeated feature rows as augmentation.
if nargin<2, c=project_config(); end
if nargin<3, seed=c.seed; end
rng(seed,'twister');
N=nPerClass*numel(c.classes);
S=table((1:N)',zeros(N,1),zeros(N,1),zeros(N,1),zeros(N,1), ...
    zeros(N,1),zeros(N,1),zeros(N,1),zeros(N,1),zeros(N,1), ...
    'VariableNames',{'id','classId','distanceKm','Rf','Rg','tOn', ...
    'loadScale','Ssc','sourcePhase','tOff'});
for k=1:N
    S.classId(k)=ceil(k/nPerClass);
    S.distanceKm(k)=0.5+9*rand;
    S.Rf(k)=10^(-2+2.7*rand);  % 0.01 to about 5 ohm, each phase branch
    S.Rg(k)=10^(-2+3*rand);    % 0.01 to 10 ohm, common ground branch
    S.tOn(k)=round((0.10+0.02*rand)/c.Ts)*c.Ts;
    S.tOff(k)=0.30;           % after stop time: no clearing-label ambiguity
    S.loadScale(k)=0.5+0.5*rand;
    S.Ssc(k)=c.Ssc*(0.8+0.4*rand);
    S.sourcePhase(k)=-180+360*rand;
end
end
