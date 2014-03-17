% written by Liefeng Bo in University of Washington 02/04/2012

clear;

% add paths
addpath('../kdes');
addpath('../emk');
addpath('../helpfun');
addpath(genpath('../liblinear-1.5-dense-float'));

tic;
% initialize the directories of image
imdir = '../images/sports/';
[sportslabel, impath] = get_im_label(imdir);

% initialize the parameters of kdes
kdes_params.grid = 8;   % kdes is extracted every 8 pixels
kdes_params.patchsize = 16;  % patch size
kdes_params.kdestype{1} = 'gradkdes';
kdes_params.kdestype{2} = 'lbpkdes';
kdes_params.kdestype{3} = 'rgbkdes';

% initialize the parameters of data
data_params.datapath = impath;
data_params.tag = 1;
data_params.minsize = 45;  % minimum size of image
data_params.maxsize = 300; % maximum size of image
data_params.savedir = '../kdesfeatures/sports';

% extract kernel descriptors on training set
savedirtrain = gen_kdes_batch_all(data_params, kdes_params);

% initialize the parameters of basis vectors
basis_params.samplenum = 50; % maximum sample number per image scale
basis_params.wordnum = 3000; % number of visual words
% initialize the parameters of emk
emk_params.pyramid = [1 2 3 4];
emk_params.ktype = 'rbf';
kparam = [0.001, 0.01, 0.01];
sportsfea_all = [];
for i = 1:length(kdes_params.kdestype)
  % learn visual words using K-means
  fea_params.feapath = get_kdes_path(savedirtrain{i});
  sportswords = visualwords(fea_params, basis_params);
  % extrac emk features
  basis_params.basis = sportswords;
  emk_params.kparam = kparam(i);
  sportsfea = cksvd_emk_batch(fea_params, basis_params, emk_params);
  sportsfea_all = [sportsfea_all; single(sportsfea)];
end

% test features with linear SVMs
lc = 10; % regularization parameter C
trail = 10; % results averaged over 5 runs
trainnum = 70; % 70 training images per category
testnum = 60; % 60 test images per category
for i = 1:trail

    % generate training and test partitions
    indextrain = [];
    indextest = [];
    labelnum = unique(sportslabel);
    for j = 1:length(labelnum)
        index = find(sportslabel == j);
        perm = randperm(length(index));
        indextrain = [indextrain index(perm(1:trainnum))];
        indextest = [indextest index(perm(trainnum+1:(trainnum+testnum)))];
    end

    % generate training and test samples
    trainkdes = sportsfea_all(:, indextrain);
    trainlabel = sportslabel(:, indextrain);
    testkdes = sportsfea_all(:, indextest);
    testlabel = sportslabel(:, indextest);

    % classify with liblinear
    disp('Train linear SVM ... ...');
    lc = 1; % regularization parameter C
    option = ['-s 1 -c ' num2str(lc)];
    [trainkdes, minvalue, maxvalue] = scaletrain(trainkdes, 'power');
    testkdes = scaletest(testkdes, 'power', minvalue, maxvalue);
    model = train(trainlabel',trainkdes',option);
    [predictlabel, accuracy, decvalues] = predict(testlabel', testkdes', model);
    sports_acc_lsvm_allkdes(i,1) = mean(predictlabel == testlabel');

    % print and save classification accuracy
    disp(['Accuracy of Liblinear is ' num2str(mean(sports_acc_lsvm_allkdes))]);
    save('./results/sports_acc_lsvm_allkdes.mat', 'sports_acc_lsvm_allkdes');
end
totaltime = toc;
disp(['Total running time is ' num2str(totaltime)]);


