function D=generate_dataset(S,c,folder)
% Saves every raw case, so interrupted jobs can be resumed with the same S/c.
if nargin<2, c=project_config(); end
if nargin<3, folder='data'; end
if ~exist(folder,'dir'), mkdir(folder); end
manifest=fullfile(folder,'manifest.mat');
if exist(manifest,'file')
    old=load(manifest);
    assert(isequaln(old.S,S)&&isequaln(old.c,c), ...
        'Existing data uses another configuration. Choose a new folder.');
else
    save(manifest,'S','c');
end
D.X=[]; D.bits=[]; D.fault=[]; D.distance=[]; D.group=[];
D.classId=[]; D.jointValid=[]; D.time=[];
for k=1:height(S)
    file=fullfile(folder,sprintf('case_%05d.mat',S.id(k)));
    if exist(file,'file'), tmp=load(file,'raw'); raw=tmp.raw;
    else, raw=simulate_case(S(k,:),c); save(file,'raw'); end
    [X,t,valid]=extract_features(raw,c);
    s=S(k,:); faulty=(s.classId>1) & t>=s.tOn & t<s.tOff;
    if s.classId==1
        use=take(find(valid),60);
    else
        pre=find(valid & t<s.tOn);
        early=find(valid & t>=s.tOn & t<s.tOn+1/c.f0);
        settled=find(valid & t>=s.tOn+1/c.f0 & t<min(s.tOff,c.stopTime));
        use=unique([take(pre,20) take(early,20) take(settled,40)]);
    end
    f=double(faulty(use)); n=numel(use);
    bits=c.bits(s.classId,:)'*f;
    cls=ones(1,n); cls(logical(f))=s.classId;
    D.X=[D.X X(:,use)]; D.bits=[D.bits bits];
    D.fault=[D.fault f]; D.distance=[D.distance s.distanceKm*f];
    D.group=[D.group repmat(s.id,1,n)]; D.classId=[D.classId cls];
    D.jointValid=[D.jointValid (~logical(f) | t(use)>=s.tOn+1/c.f0)];
    D.time=[D.time t(use)];
    fprintf('Simulated/loaded %d of %d scenarios\n',k,height(S));
end
D.S=S; D.c=c; save(fullfile(folder,'dataset.mat'),'D','-v7.3');
end
function y=take(x,n)
if isempty(x), y=[]; else, y=x(unique(round(linspace(1,numel(x),min(n,numel(x)))))); end
end
