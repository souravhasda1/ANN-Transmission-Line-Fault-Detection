function ids=decode_fault(bits,c)
% 1..12 for valid bit patterns; 0 for Unknown/invalid. No nearest-class guessing.
if nargin<2, c=project_config(); end
assert(size(bits,1)==4); ids=zeros(1,size(bits,2));
for k=1:size(bits,2)
    j=find(all(c.bits==double(bits(:,k)'),2),1);
    if ~isempty(j), ids(k)=j; end
end
end
