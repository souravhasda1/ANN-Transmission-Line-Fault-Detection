function [X,t,valid]=extract_features(raw,c)
% Causal full-cycle RMS, then decimation to 1 ms. X is 8-by-N.
% Never form zero-sequence by adding the three positive RMS magnitudes.
if nargin<2, c=project_config(); end
dt=diff(raw.t);
assert(max(abs(dt-c.Ts))<c.Ts*1e-4,'Expected uniformly sampled electrical signals.');
N=c.window;
wave=[raw.V raw.I mean(raw.V,2) mean(raw.I,2)];
sq=filter(ones(N,1)/N,1,wave.^2); % only present and past samples
r=sqrt(max(sq,0));
b=[c.Vbase c.Vbase c.Vbase c.Ibase c.Ibase c.Ibase c.Vbase c.Ibase];
r=r./b;
hop=round(c.featureStep/c.Ts);
assert(abs(hop*c.Ts-c.featureStep)<1e-12);
ix=1:hop:numel(raw.t);
X=r(ix,:)'; t=raw.t(ix)';
valid=(ix>=N) & (t>=c.blankTime);
end
