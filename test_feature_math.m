function test_feature_math()
% Small, toolbox-free checks of physical feature math and class encoding.
c=project_config(); t=(0:c.Ts:0.1)'; a=2*pi*c.f0*t+[0 -2*pi/3 2*pi/3];
raw.t=t; raw.V=sqrt(2)*c.Vbase*sin(a); raw.I=sqrt(2)*c.Ibase*sin(a-0.2);
[X,~,valid]=extract_features(raw,c);
assert(max(abs(X(1:6,valid)-1),[],'all')<1e-8);
assert(max(abs(X(7:8,valid)),[],'all')<1e-8);
assert(isequal(decode_fault(c.bits',c),1:12));
% Causality: changing future samples must not change past features.
altered=raw; altered.V(t>0.07,:)=100*altered.V(t>0.07,:);
[Y,tf]=extract_features(altered,c);
assert(isequal(X(:,tf<=0.07),Y(:,tf<=0.07)));
disp('Feature RMS, zero sequence, decoder, and causality checks passed.');
end
