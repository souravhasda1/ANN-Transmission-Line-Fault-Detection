function split=split_scenarios(D)
% All windows of a simulation stay together. Stratify by scenario fault class.
rng(D.c.seed+1,'twister');
tr=[]; va=[]; te=[];
for cls=1:numel(D.c.classes)
    ids=D.S.id(D.S.classId==cls)'; n=numel(ids);
    assert(n>=10,'Use at least 10 scenarios/class for a train/validation/test run.');
    ids=ids(randperm(n)); a=floor(0.70*n); b=floor(0.15*n);
    tr=[tr ids(1:a)]; va=[va ids(a+1:a+b)]; te=[te ids(a+b+1:end)];
end
split.train=find(ismember(D.group,tr));
split.val=find(ismember(D.group,va));
split.test=find(ismember(D.group,te));
assert(isempty(intersect(tr,va))&&isempty(intersect(tr,te))&&isempty(intersect(va,te)));
split.trainGroups=tr; split.valGroups=va; split.testGroups=te;
end
