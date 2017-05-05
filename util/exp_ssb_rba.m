function exp_ssb_rba(D,y,varargin)
% Sample selection bias experiment for Robust Bias-Aware

% Size
[M,~] = size(D);

% Parse arguments
p = inputParser;
addOptional(p, 'nN', min(10, round(M./2)));
addOptional(p, 'nM', M);
addOptional(p, 'setDiff', false);
addOptional(p, 'nR', 1);
addOptional(p, 'nF', 5);
addOptional(p, 'gamma', 1);
addOptional(p, 'lambda', 1);
addOptional(p, 'clip', 100);
addOptional(p, 'iwe', 'kliep')
addOptional(p, 'maxIter', 500);
addOptional(p, 'xTol', 1e-5);
addOptional(p, 'prep', {''});
addOptional(p, 'svnm', []);
parse(p, varargin{:});

% Normalize data
D = da_prep(D, p.Results.prep);

% Number of sample sizes
lNN = length(p.Results.nN);
if isempty(p.Results.nM)
    lNM = 1;
else
    lNM = length(p.Results.nM);
end

% Preallocate
theta = cell(p.Results.nR,lNN,lNM);
w = cell(p.Results.nR,lNN,lNM);
e = NaN(p.Results.nR,lNN,lNM);
R = NaN(p.Results.nR,lNN,lNM);
pred = cell(p.Results.nR,lNN,lNM);
post = cell(p.Results.nR,lNN,lNM);
AUC = NaN(p.Results.nR,lNN,lNM);

for r = 1:p.Results.nR
    disp(['Running repeat ' num2str(r) '/' num2str(p.Results.nR)]);
    
    for n = 1:lNN
        
        % Select samples
        ix = ssb_nhg(D,y,p.Results.nN(n), 'loc', 'edge', 'type', 'Gaussian', 'viz', false);
        
        % Select source
        X = D(ix,:);
        yX = y(ix);
        
        % Select target
        if p.Results.setDiff
            Z = D(setdiff(1:M,ix),:);
            yZ = y(setdiff(1:M,ix));
        else
            Z = D;
            yZ = y;
        end
        
        for m = 1:lNM
            
            % Select target samples
            if ~isempty(p.Results.nM)
                ixnM = randsample(1:M, p.Results.nM(m), false);
            else
                ixnM = 1:size(Z,1);
            end
            
            % Cross-validate regularization parameter
            if isempty(p.Results.lambda)
                disp(['Cross-validating for regularization parameter']);
                
                % Set range of regularization parameter
                Lambda = [0 10.^[-6:2:0]];
                R_la = zeros(1,length(Lambda));
                for la = 1:length(Lambda)
                    
                    % Split folds
                    ixFo = randsample(1:p.Results.nF, length(ixNN), true);
                    for f = 1:p.Results.nF
                        
                        % Train on included folds
                        theta_f = rba(X(ixFo~=f,:),yX(ixFo~=f),Z(ixnM,:), 'xTol',p.Results.xTol,'maxIter', p.Results.maxIter, 'gamma', p.Results.gamma, 'lambda', Lambda(la), 'clip', p.Results.clip, 'iwe', p.Results.iwe);
                        
                        % Evaluate on held-out source folds (MSE)
                        Xa = [X(ixFo==f,:) ones(length(ixFo==f),1)];
                        yXf = yX(ixFo==f);
                        for j = 1:size(Xa,1)
                            R_la(la) = R_la(la) + (-Xa(j,:)*theta_f(yXf(j),:)' + log(sum(exp(Xa(j,:)*theta_f'))));
                        end
                        R_la(la) = R_la(la)./size(Xa,1);
                    end
                end
                % Select minimal
                R_la(isinf(R_la)) = NaN;
                [~,ixMinLambda] = min(R_la);
                lambda = Lambda(ixMinLambda);
            else
                lambda = p.Results.lambda;
            end
            disp(['\lambda = ' num2str(lambda)]);
            
            % Call classifier and evaluate
            [theta{r,n,m},w{r,n,m},R(r,n,m),e(r,n,m),pred{r,n,m},post{r,n,m},AUC(r,n,m)] = rba(X,yX,Z(ixnM,:), 'yZ', yZ(ixnM), 'xTol',p.Results.xTol,'maxIter', p.Results.maxIter, 'gamma', p.Results.gamma, 'lambda', lambda, 'clip', p.Results.clip, 'iwe', p.Results.iwe);
            
        end
    end
end

% Write results
di = 1; while exist(['results_rba_' p.Results.svnm num2str(di) '.mat'], 'file')~=0; di = di+1; end
fn = ['results_rba_' p.Results.svnm num2str(di)];
disp(['Done. Writing to ' fn]);
save(fn, 'theta', 'R','w','e', 'pred', 'post', 'AUC','p');

end
