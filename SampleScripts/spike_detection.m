
%% Establish IEEG Sessions
% Establish IEEG Sessions through the IEEGPortal. This will allow on demand
% data access

%add folders to path
addpath(genpath('../../../../Libraries/ieeg-matlab-1.13.2'));
addpath(genpath('../portalGit/Analysis'))
addpath(genpath('../portalGit/Utilities'))

%Load data
params = initialize_task_spike;
% Load data
session = loadData(params);
 
% % Get training set
train_layers = {'PFC'};
allThreshold = cell(numel(session.data),1);
winLen = zeros(numel(session.data),1);
durations = cell(numel(session.data),1);
recommended_multiplier =  cell(numel(session.data),1);
for i = 1:numel(session.data)
    [wL, tmp_rec_mult,thres,dur,numMiss] = getHypersensitiveParams(session.data(i),train_layers{1},'pad_mult',2,'background_thres_mult', ...
        3.5,'show_plots',0,'find_nearest_peak',1);
    allThreshold{i} = thres;
    winLen(i) = min(wL);
    durations{i} = dur;
    recommended_multiplier{i} = tmp_rec_mult;
    %catch
    %end
end

%
allThreshold;

channelIdxs = cell(numel(session.data),1);
for i = 1:numel(session.data)
    channelIdxs{i} = 1:numel(session.data(i).rawChannels)
end

% params.timeOfInterest=[];%[0 60*60*24];
% params.filtFlag = 0;
% params.blockLen = 15*60*1; 
% for i =1
%     params.winLen = winLen(i);
%     params.winDisp = winLen(i);
%     spike_detecotr_general(session.data(i),channelIdxs{i},',{'LL'});
% end

i = 1
allDat = getAllData(session.data(i),3,3600);
fs = session.data(i).sampleRate;
LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');
LLFn = @(x) (abs(diff(x)));
feats = LLFn2(allDat,winLen(i)*fs);
feats2 = LLFn(allDat);

[pks loc] = findpeaks(feats,'MinPeakHeight',allThreshold{i}(:,3));
loc(loc<(2*fs)) = [];
ch = cell(numel(loc),1);
for chi = 1:numel(loc)
    ch{chi} = 3;
end
eventMarking(session.data(i),[(loc/fs-0.05)*1e6 (loc/fs+0.2)*1e6],ch,'numToVet',30,'intelligent',1,'feature_params', ...
   {'cwt'})

%idx = cellfun(@(x)numel(x)>1,eventChannels);
%layerName = 'burst-candidate';
%eventMarking(session.data(i),eventTimesUSec(idx,:),eventChannels(idx),layerName)

%add marked bursts to correct layer
%[~, times, channels] = getAnnotations(session.data(i),train_layers{1});
%uploadAnnotations(session.data(i),'Type B',times,channels,'Type B','append')


%load true and false layers (Type A, Type B, get features, train, and
%classify rest)
%[~, falseTimes, falseChannels] = getAnnotations(session.data(i),'Type A');
%[~, trueTimes, trueChannels] = getAnnotations(session.data(i),'Type B');

runOnWin = 0;
feat = runFuncOnAnnotations(session.data(i),'Type A',@features_comprehensive,'runOnWin',0,'useAllChannels',0);

%
feat2 = runFuncOnAnnotations(session.data(i),'Type B',@features_comprehensive,'runOnWin',0,'useAllChannels',1);
%run on origin markings
feat2 = runFuncOnAnnotations(session.data(i),'PFC',@features_comprehensive,'runOnWin',0,'useAllChannels',1);

trainset = [cell2mat(feat);cell2mat(feat2)];
labels = [zeros(numel(feat),1);ones(numel(feat2),1)];

load('RFmod.mat');
% 
% mod = TreeBagger(300,trainset,labels,'method','Classification','OOBPredictorImportance','on','Cost',[0 1; 2 0]);
% save('RFmod.mat','mod');
% oobErrorBaggedEnsemble = oobError(mod);
% plot(oobErrorBaggedEnsemble)
% xlabel 'Number of grown trees';
% ylabel 'Out-of-bag classification error';
% 
% 
% [yhat,scores] = oobPredict(mod);
% [conf, classorder] = confusionmat(categorical(labels), categorical(yhat))
% disp(dataset({conf,classorder{:}}, 'obsnames', classorder));
% 
% imp = mod.OOBPermutedPredictorDeltaError;
% predictorNames = {};
% for i = 1:60
%     predictorNames{i} = sprintf('%d',i');
% end
% figure;
% bar(imp);
% ylabel('Predictor importance estimates');
% xlabel('PC');
% h = gca;
% h.XTick = 1:2:60
% h.XTickLabel = predictorNames
% h.XTickLabelRotation = 45;
% h.TickLabelInterpreter = 'none';

load(sprintf('%s-burstspatial.mat',session.data(i).snapName));
test.eventChannels = eventChannels;
test.eventTimesUSec = eventTimesUSec;
[yhat yhat_scores] = testModelOnAnnotations_par(session.data(i),'Type B',mod,@features_comprehensive,'runOnWin',0,'useAllChannels',1,'customTimeWindows',test);

