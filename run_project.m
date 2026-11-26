% Run from this project folder, or run individual stages as explained in GUIDE.
clear; clc; close all;
c=project_config();
if ~exist([c.model '.slx'],'file'), build_power_model(c); end
smoke_test();
% 10/class checks the pipeline only; 80/class is a suggested first study.
% Increase diversity and add challenge cases before making accuracy claims.
S=make_scenarios(10,c);
D=generate_dataset(S,c,'data_pilot');
M=train_dual_ann(D);
R=evaluate_dual_ann(M,D);
% Replay a genuinely held-out FAULT scenario, not a training scenario.
id=M.split.testGroups(find(ismember(M.split.testGroups,D.S.id(D.S.classId>1)),1));
tmp=load(fullfile('data_pilot',sprintf('case_%05d.mat',id)),'raw');
replay_case(M,tmp.raw);
if ~exist('ann_relay_replay.slx','file'), build_relay_demo(M,tmp.raw); end
