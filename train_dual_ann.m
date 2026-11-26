function M=train_dual_ann(D)
% Two 8-20-10-output feedforward networks, matching reference architecture.
% Distances are per-unit line length. Healthy distance errors have zero weight.
assert(exist('feedforwardnet','file')==2,'Deep Learning Toolbox is required.');
c=D.c; split=split_scenarios(D); rng(c.seed+2,'twister');
mu=mean(D.X(:,split.train),2); sigma=std(D.X(:,split.train),0,2);
sigma(sigma<1e-8)=1; X=(D.X-mu)./sigma;
det=newnet(1); det=configure(det,X(:,split.train),D.fault(:,split.train));
det.divideFcn='divideind'; det.divideParam.trainInd=split.train;
det.divideParam.valInd=split.val; det.divideParam.testInd=[];
EW=ones(size(D.fault));
for value=0:1
    n=sum(D.fault(split.train)==value);
    EW(D.fault==value)=numel(split.train)/(2*max(n,1));
end
[det,trD]=train(det,X,D.fault,[],[],EW);
T=[D.bits;D.distance/c.lineKm];
W=ones(size(T)); W(5,D.fault==0)=0; % healthy distance has no physical meaning
joint=newnet(5); jj=split.train(logical(D.jointValid(split.train)));
jv=split.val(logical(D.jointValid(split.val)));
joint=configure(joint,X(:,jj),T(:,jj));
joint.divideFcn='divideind'; joint.divideParam.trainInd=jj;
joint.divideParam.valInd=jv; joint.divideParam.testInd=[];
[joint,trJ]=train(joint,X,T,[],[],W);
M.det=det; M.joint=joint; M.mu=mu; M.sigma=sigma; M.c=c; M.split=split;
M.detTraining=trD; M.jointTraining=trJ;
% Threshold selection uses validation only. Maximize balanced accuracy.
p=det(X(:,split.val)); truth=logical(D.fault(split.val));
grid=0.05:0.05:0.95; score=zeros(size(grid));
for k=1:numel(grid)
    y=p>=grid(k);
    score(k)=0.5*(mean(y(truth))+mean(~y(~truth)));
end
[~,best]=max(score); M.c.detectorThreshold=grid(best);
save('trained_dual_ann.mat','M','-v7.3');
fprintf('Validation-selected detector threshold: %.2f\n',M.c.detectorThreshold);
end
function net=newnet(nout)
net=feedforwardnet([20 10],'trainlm');
net.inputs{1}.processFcns={}; net.outputs{3}.processFcns={};
net.layers{1}.transferFcn='tansig'; net.layers{2}.transferFcn='tansig';
net.layers{3}.transferFcn='purelin'; net.performFcn='mse';
net.trainParam.epochs=300; net.trainParam.max_fail=12;
net.trainParam.showWindow=false;
% configure() determines output dimension; nout documents intent.
assert(ismember(nout,[1 5]));
end
