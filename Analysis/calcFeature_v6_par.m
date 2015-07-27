function parFeats = calcFeature_v6_par(dataset,params,feature)
%Usage: calcFeature_v4(datasets,channels,feature,winLen,outLabel,filtFlag,varargin)
%This function will divide IEEGDataset channels into blocks of
%and within these blocks further divide into winLen. Features
%will be calculated for each winLen and saved in a .mat matrix.
%Features calculated: power, LL, DCN
%
% Hoameng Ung - University of Pennsylvania
% 6/15/2014 - v2 - added filter options
% 8/28/2014 - v3 - edited comments, filter options, blockLenSecsaz
% 9/18/2014 - v4 - changed winLen to winPts for generality across sampling
% rates
    blockLenSecs = params.blockLen; %get data in blocks
    feature = lower(feature);
    channels = params.channels;
    winLen = params.winLen;
    winDisp = params.winDisp;
    filtFlag = params.filtFlag;
    timeOfInterest= params.timeOfInterest; %times of interest, if empty, use entire dataset
    %% Anonymous functions
    CalcNumWins = @(xLen, fs, winLen, winDisp)floor((xLen-(winLen-winDisp)*fs)/(winDisp*fs));
    DCNCalc = @(data) (1+(cond(data)-1)/size(data,2)); % DCN feature
    AreaFn = @(x) mean(abs(x));
    EnergyFn = @(x) mean(x.^2);
    ZCFn = @(x) sum((x(1:end-1,:)>repmat(mean(x),size(x,1)-1,1)) & x(2:end,:)<repmat(mean(x),size(x,1)-1,1) | (x(1:end-1,:)<repmat(mean(x),size(x,1)-1,1) & x(2:end,:)>repmat(mean(x),size(x,1)-1,1)));
    LLFn = @(x) mean(abs(diff(x)));
    LLFn2 = @(X, winLen) conv2(abs(diff(X,1)),  repmat(1/winLen,winLen,1),'same');


    %% Initialization
    IEEGid = params.IEEGid;
    IEEGpwd = params.IEEGpwd;
    datasetFN = dataset.snapName;
    fs = dataset.channels(1).sampleRate;
    if isempty(timeOfInterest)
        duration = dataset.channels(1).get_tsdetails.getDuration/1e6;
    else
        duration =(timeOfInterest(2) - timeOfInterest(1));
    end
    startPt = 1+(timeOfInterest(1)*fs);
    numPoints = duration*fs;
    numParBlocks = 5;
    numPointsPerParBlock = numPoints / numParBlocks;
    %calculate number of blocks
    numBlocks = ceil(numPointsPerParBlock/fs/blockLenSecs);

    parFeats = cell(numParBlocks,1);
    %pool(numParBlocks);
parfor i = 1:numParBlocks
        session = IEEGSession(datasetFN,IEEGid,IEEGpwd);
        %% Feature extraction loop
        feat = cell(numBlocks,1);
        reverseStr = '';
        startParPt = startPt + (i-1)*numPointsPerParBlock;
        for j = 1:numBlocks
            %Get data
            startBlockPt = startParPt+(blockLenSecs*(j-1)*fs);
            endBlockPt = startParPt+min(blockLenSecs*j*fs,numPointsPerParBlock)-1;
            %get data
            try
                blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
            catch
                pause(1);
                blockData = session.data.getvalues(startBlockPt:endBlockPt,channels);
            end
                percentValid = 1-sum(isnan(blockData),1)/size(blockData,1);
                nChan = numel(channels);
            if strcmp(feature,'burst')
                [timesUSec, chan] = burstDetector(blockData,fs,params.channels,params);
                feat{j} = [startBlockPt/fs*1e6+timesUSec chan];
            else
                numWins = CalcNumWins(size(blockData,1),fs,winLen,winDisp);
                tmpFeat = nan(numWins,nChan);
                for n = 1:numWins
                    startWinPt = round(1+(winLen*(n-1)*fs));
                    endWinPt = round(min(winLen*n*fs,size(blockData,1)));
                    tmpData = blockData(startWinPt:endWinPt,:);
                    switch feature
                        case 'power'
                            for c = 1:nChan
                                y = tmpData(:,c);
                                [PSD,F]  = pwelch(y,ones(length(y),1),0,length(y),fs,'psd');
                                tmpFeat(n,c) = bandpower(PSD,F,[8 12],'psd');
                            end
                        case 'dcn'
                            tmpFeat(n,1) = DCNCalc(tmpData);
                        case 'll'
                            a = diff(isnan(tmpData)); %find pts starting and ending with nan
                            if sum(sum(abs(a)))~=0 %if there are nans
                                for ch = 1:size(tmpData,2);
                                    validStart = find(a(:,ch)==-1);
                                    validStop = find(a(:,ch)==1);
                                    %if unequal number of start and stops
                                    if numel(validStart)~=numel(validStop)
                                        if isempty(validStart)
                                            validStart=1;
                                        elseif isempty(validStop)
                                            validStop= size(tmpData,1);
                                        elseif validStop(1) < validStart(1) %if start is less than stop, clip starts with valid 
                                            validStart = [0; validStart];
                                        else
                                            validStop = [validStop;size(tmpData,1)];
                                        end
                                    end
                                    validIdxs = [validStart+1 validStop]; %add one since diff shifts to the left
                                    subFeat = zeros(size(validIdxs,1),1); % store feat of each clip
                                    for k = 1:size(validIdxs,1);
                                        subFeat(k) = sum(abs(diff(tmpData(validIdxs(k,1):validIdxs(k,2),ch))));
                                    end
                                    idxsPerClip = validIdxs(:,2)-validIdxs(:,1);
                                    tmpFeat(n,ch) = mean(subFeat./idxsPerClip);%/sum(idxsPerClip)); %normalize by number of points in clip
                                end
                            else
                                tmpFeat(n,:) = LLFn(tmpData);
                            end
                    end
                end
                feat{j} = tmpFeat;
            end
            percentDone = 100 * j / numBlocks;
            msg = sprintf('Percent done worker %d: %3.1f',i,percentDone); %Don't forget this semicolon
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
        fprintf('\n');
        feat = cell2mat(feat);
        if strcmp(feature,'dcn')
            feat = feat(:,1);
        end
        parFeats{i} = feat;
end
    if strcmp(feature,'burst')
        tmp = cell2mat(parFeats);
        eventTimesUSec = tmp(:,1:2);
        eventChannels = tmp(:,3);
        save([datasetFN '_' params.burst.saveLabel '.mat'],'eventTimesUSec','eventChannels','-v7.3');
    else
        save([datasetFN '_' params.saveLabel '.mat'],'parFeats','-v7.3');
    end
end




function [timesUSec, chan] = burstDetector(data, fs, channels, params)

orig = data;
%filter data
if params.burst.FILTFLAG == 1
    for i = 1:size(data,2);
        [b, a] = butter(4,[1/(fs/2)],'high');
        d1 = filtfilt(b,a,data(:,i));
        try
        [b, a] = butter(4,[70/(fs/2)],'low');
        d1 = filtfilt(b,a,d1);
        catch
        end
        [b, a] = butter(4,[58/(fs/2) 62/(fs/2)],'stop');
         d1 = filtfilt(b,a,d1);
        data(:,i) = d1;
    end
end                 

if params.burst.DIAGFLAG
    T = 1/fs;                     % Sample time
    L = length(orig(:,1));                     % Length of signal
    subplot(2,2,1)
    plot(orig(:,1));
    subplot(2,2,3)
    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft(d1,NFFT)/L;
    f = fs/2*linspace(0,1,NFFT/2+1);

    % Plot single-sided amplitude spectrum.
    plot(f,2*abs(Y(1:NFFT/2+1))) 
    title('Single-Sided Amplitude Spectrum of y(t)')
    xlabel('Frequency (Hz)')
    ylabel('|Y(f)|')

    NFFT = 2^nextpow2(L); % Next power of 2 from length of y
    Y = fft(d1,NFFT)/L;
    f = fs/2*linspace(0,1,NFFT/2+1);
    subplot(2,2,3)
    plot(d1);
    subplot(2,2,4)
    % Plot single-sided amplitude spectrum.
    plot(f,2*abs(Y(1:NFFT/2+1))) 
    title('Single-Sided Amplitude Spectrum of y(t)')
    xlabel('Frequency (Hz)')
    ylabel('|Y(f)|')  
end


featWinLen = round(params.burst.winLen * fs);

featVals = params.burst.featFN(data, featWinLen);

medFeatVal = nanmedian(featVals);
nfeatVals = bsxfun(@rdivide, featVals,medFeatVal);

  % get the time points where the feature is above the threshold (and it's not
  % NaN)
  aboveThresh = ~isnan(nfeatVals) & nfeatVals > params.burst.thres & nfeatVals<params.burst.maxThres;
  
aboveThreshPad = aboveThresh;
  %get event start and end window indices - modified for per channel
  %processing
   [evStartIdxs, chan] = find(diff([zeros(1,size(aboveThreshPad,2)); aboveThreshPad]) == 1);
   [evEndIdxs, ~] = find(diff([aboveThreshPad; zeros(1,size(aboveThreshPad,2))]) == -1);
   evEndIdxs = evEndIdxs + 1;

  startTimesSec = evStartIdxs/fs;
  endTimesSec = evEndIdxs/fs;
  
  if numel(channels) == 1
      channels = [channels channels];
  end
  %map chan idx back to channels
  chan = channels(chan);
  
  duration = endTimesSec - startTimesSec;
  idx = (duration<(params.burst.minDur) | (duration>params.burst.maxDur));
  startTimesSec(idx) = [];
  endTimesSec(idx) = [];
  chan(idx) = [];
  timesUSec = [startTimesSec*1e6 endTimesSec*1e6];
  chan = chan';
end



