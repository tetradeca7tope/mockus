function [decomp, boAddParams, numGroups] = ...
  getDecompForParams(numDims, numDimsPerGroup, boAddParams)

  numGroups = floor(numDims/numDimsPerGroup);

  if strcmp(boAddParams.decompStrategy, 'known')
    decomp = cell(numGroups, 1);
    boAddParams.noises = 0 * ones(numGroups, 1);
    for i = 1:numGroups
      decomp{i} = ( (i-1)*numDimsPerGroup+1 : i*numDimsPerGroup );
    end

  else
    decomp.d = numDimsPerGroup;
    decomp.M = numGroups;
  end

end

