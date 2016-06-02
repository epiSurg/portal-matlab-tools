<<<<<<< HEAD
function removeAnnots(datasets,exp,varargin)
%function will remove all annotation layers matching regexp exp from IEEGDatasets. 
%CAUTION: WILL PERMANENTLY REMOVE 
%varargin: 'channels': vector to specific which channels to remove
%annotations from

chanSpec = [];
for i = 1:2:numel(varargin)
    switch(varargin{i})
        case 'channels'
            chanSpec = varargin{i+1};
            fprintf('Removing channel specific\n');
    end
end

for i = 1:numel(datasets)
    fprintf('Removing layers from %s \n',datasets(i).snapName);
    layers = [datasets(i).annLayer];
    layerNames = {layers.name};
    tmp = cellfun(@(x)regexpi(x,exp)>0,layerNames,'UniformOutput',0);
    tmp = cellfun(@(x)(~isempty(x)),tmp);
    layerIdxs = find(tmp~=0);
    if isempty(layerIdxs)
        fprintf('No layers found\n');
    else
        for j = layerIdxs
            %if no channels specified, remove entire layer
            if isempty(chanSpec)
              %  resp = input(sprintf('Remove layer %s ...? (y/n): ',layerNames{j}),'s');
              %  if strcmp(resp,'y')
                    try
                        datasets(i).removeAnnLayer(layerNames{j});
                        fprintf('...done!\n');
                    catch ME
                        fprintf('...fail! %s\n',ME.exception);
                    end
             %   end
            else 
                [annots, times, chan] = getAllAnnots(datasets(i),layerNames{j});
            end
        end
    end
=======
function removeAnnots(datasets,exp)
%function will remove all annotation layers matching regexp exp from IEEGDatasets. 
%CAUTION: WILL PERMANENTLY REMOVE 
%v2 7/28/2015 - Updated to support ieeg-matlab-1.13.2


for i = 1:numel(datasets)
    fprintf('Removing layers from %s \n',datasets(i).snapName);
    try
    layers = [datasets(i).annLayer];
    layerNames = {layers.name};
    tmp = cellfun(@(x)regexp(x,exp)>0,layerNames,'UniformOutput',0);
    tmp = cellfun(@(x)(~isempty(x)),tmp);
    layerIdxs = find(tmp~=0);
        for j = layerIdxs
            resp = input(sprintf('Remove layer %s ...? (y/n): ',layerNames{j}),'s');
            if strcmp(resp,'y')
                try
                    datasets(i).removeAnnLayer(layerNames{j});
                    fprintf('...done!\n');
                catch
                    fprintf('...fail!\n');
                end
            end
        end
    catch
        fprintf('No layers found\n');
    end
    
>>>>>>> 45667d6cb1273defd11272f8308fddcc159728fe
end