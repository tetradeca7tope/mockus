% Experiment Set up for Bayesian Optimization and GP Bandits

close all;
clear all;
LIBPATH = '~/libs/kky-matlab/';
addpath([LIBPATH 'utils']); 
addpath([LIBPATH 'ancillary']); 
addpath([LIBPATH 'GPLibkky']); 
addpath ../BOLibkky/
addpath ../addGPLibkky/
addpath ../utils/

warning off;

uTest = true;

if ~uTest
% Fixed experiment parameters
numExperiments = 3;
numDiRectEvals = 500;
numIters = 300;
else
% Unit text experiment parameters
numExperiments = 2;
numDiRectEvals = 5;
numIters = 30;
end

% Problem parameters
numDims = 6;
trueNumDimsPerGroup = 2;
numDimsPerGroupCands = [1 2 3 4 5 6]';
numdCands = numel(numDimsPerGroupCands);

% Get the function
[func, funcProperties] = getAdditiveFunction(numDims, trueNumDimsPerGroup);
bounds = funcProperties.bounds;
trueDecomp = funcProperties.decomposition;
trueMaxVal = funcProperties.maxVal;
trueMaxPt = funcProperties.maxPt;
trueNumGroups = numel(trueDecomp);

% Ancillary stuff
resultsDir = 'results/';
saveFileName = sprintf('%stoyExp-%d-%d-%s.mat', resultsDir, numDims, ...
  trueNumDimsPerGroup, datestr(now,'ddmm-hhMMss') );

% Compute some statistics to help with the initialization
th = rand(1000, numDims); fth = func(th);
meanFth = mean(fth);
stdFth = std(fth);




% Parameters for additive Bayesian optimization
boParams.optPtStdThreshold = 0.002;
boParams.alBWLB = 1e-5;
boParams.alBWUB = 5;
boParams.numInitPts = 10; 
% use the same initialization points
boParams.initPts = rand(boParams.numInitPts, numDims);
boParams.initVals = func(boParams.initPts);
boParams.commonNoise = 0.01 * stdFth;
boParams.utilityFunc = 'UCB';
boParams.meanFuncs = [];
boParams.commonMeanFunc = @(arg) zeros(size(arg, 1), 1);
boParams.useSamePr = true;
boParams.useSameSm = true;
boParams.fixPr = false;
boParams.fixSm = false;
boParams.sigmaPrRange = [0.03 30] * stdFth;
boParams.useFixedBandwidth = false;


totalNumQueries = numIters + boParams.numInitPts


% From here on customize each parameters separately.
% Initialize optimization parameters
boKDParams = boParams;
boKDParams.decompStrategy = 'known';
boKDParams.diRectParams.maxevals = ceil(numDiRectEvals/trueNumGroups);
boKDParams.diRectParams.maxits = inf;

boAddParams = boParams;
boAddParams.decompStrategy = 'partialLearn';

boUDParams = boKDParams;
boUDParams.decompStrategy = 'decide';

% Initialize arrays for storing the history
boKDHistories = zeros(numExperiments, totalNumQueries);
boAddHistories = zeros(numExperiments, totalNumQueries, numdCands);
boUDHistories = zeros(numExperiments, totalNumQueries);

% For storing simple regret values
boKDSimpleRegrets = zeros(numExperiments, totalNumQueries);
boAddSimpleRegrets = zeros(numExperiments, totalNumQueries, numdCands);
boUDSimpleRegrets = zeros(numExperiments, totalNumQueries);

% For storing cumulative regret values
boKDCumRegrets = zeros(numExperiments, totalNumQueries);
boAddCumRegrets = zeros(numExperiments, totalNumQueries, numdCands);
boUDCumRegrets = zeros(numExperiments, totalNumQueries);
dMHistAll = []; 
ptAll = [];

for expIter = 1:numExperiments

  fprintf('\n==============================================================\n');
  fprintf('Experiment %d/ %d\nMaxVal: %0.4f\n', ...
    expIter, numExperiments, trueMaxVal);
  fprintf('Num DiRectEvals: %d\n', numDiRectEvals);
  fprintf('==============================================================\n');

%  % Known true decomposition
%  fprintf('\nKnown Decomposition\n');
%  boKDParams.noises = 0 * ones(trueNumGroups, 1);
%  [~, ~, ~, valHistKD] = ...
%    bayesOptDecompAddGP(func, trueDecomp, bounds, numIters, boKDParams);
%  [sR, cR] = getRegrets(trueMaxVal, valHistKD);
%
%  boKDHistories(expIter, :) = valHistKD';
%  boKDSimpleRegrets(expIter, :) = sR';
%  boKDCumRegrets(expIter, :) = cR';

  % Learn Decomposition
  fprintf('\nKnown Grouping Unknown Decomposition\n');

  % For the candidates in numDimsPerGroupCands
  for candIter = 1:numdCands
    fprintf('\nUsing an arbitrary %d/ %d decomposition\n', ...
      numDimsPerGroupCands(candIter), numDims );

    [decompAdd, boAddParamsCurr, numCurrGroups] = ...
      getDecompForParams(numDims, numDimsPerGroupCands(candIter), ...
                  boAddParams, true);
    
    boAddParamsCurr.diRectParams.maxevals = ceil(0.9 * numDiRectEvals/numCurrGroups);
    
    [~, ~, ~, valHistAdd] = ...
      bayesOptDecompAddGP(func, decompAdd, bounds, numIters, boAddParamsCurr);
    
    [sR, cR] = getRegrets(trueMaxVal, valHistAdd);
    boAddHistories(expIter, :, candIter) = valHistAdd';
    boAddSimpleRegrets(expIter, :, candIter) = sR';
    boAddCumRegrets(expIter, :, candIter) = cR';
 
  end

  
  % Decomposition varies across iterations
  fprintf('\nChoose the decomposition at each iteration\n');
  
  % Initialize (d,M) pairs that passed to bayesOptDecideAddGP
  decomp = cell(numdCands,1);
  for i = 1:numdCands
    decomp{i}.d = numDimsPerGroupCands(i);
    decomp{i}.M = floor(numDims / decomp{i}.d);
  end

  % How to choose (d,M) pairs
  % boUDParams.choosedM = 'maxMll';
  boUDParams.choosedM = 'inOrder';
  % boUDParams.choosedM = 'normalize';
  % boUDParams.choosedM = 'maxVal';
  

  [~, ~, ~, valHistDecide,~, dMHist, ptHolder] = ...
      decide(func, decomp, bounds, numIters, boUDParams); 
  dMHistAll = [dMHistAll; dMHist];
  ptAll(expIter,:,:) = ptHolder;

  [sR, cR] = getRegrets(trueMaxVal, valHistDecide);
  
  boUDHistories(expIter, :) = valHistDecide';
  boUDSimpleRegrets(expIter, :) = sR';
  boUDCumRegrets(expIter, :) = cR';

 % Save Results at each iteration
  save(saveFileName, 'numDims', 'trueNumDimsPerGroup', 'func', ...
    'funcProperties', 'trueMaxVal',  ...
    'numIters', 'totalNumQueries', ...
    'boKDHistories', 'boAddHistories', 'boUDHistories', ...
    'boKDSimpleRegrets', 'boAddSimpleRegrets', 'boUDSimpleRegrets', ...
    'boKDCumRegrets', 'boAddCumRegrets', 'boUDCumRegrets', ...
    'numDimsPerGroupCands', 'dMHistAll','ptHolder');

end
