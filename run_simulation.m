clear
random_targets = 1;%for debugging purpuse
close all
common_axis = linspace(-100, 100, 201);
disp_axis = linspace(-50, 50, 101);

max_nTrials =100;%number of simulation trials
scotomaRad = 6;% radious of scotoma in cortical coordinates, in mm
v = -3:.1:3 ; %displacement from the neuron mean (in cortical mm)
sd_e = 0.05;% measurment noise
sd_m = 0.04;%SD of motor noise
T =30;%forgetful function constant
%% Neurons
nNeurons = 81;
%The location of each neuron is known up to a proability distributon 
%initialize the mean and SD of neurons
init_neuron_mean = linspace(-40, 40, nNeurons);
sigma_0 = 4*ones(1, nNeurons);
for i=1:nNeurons
    neuron(i).mean = init_neuron_mean(i);
    neuron(i).init_mean = init_neuron_mean(i);
    %     if i<nNeurons/2 %0%mod(i,3) == 1
    %         neuron(i).SD = 4;
    %         neuron(i).init_SD = 4;
    %     else
    neuron(i).SD = sigma_0(i);
    neuron(i).init_SD = sigma_0(i);
    %
    %     end
end
cnt = zeros(1, nNeurons);
%% saccade targets
num_biased_trials = 10;%on these trials, the target is forced to be on the left (or right)  
left_biased = 0;
right_biased = 0;

sct_ind = (nNeurons+1)/2-scotomaRad : (nNeurons+1)/2+scotomaRad;%where scotoma falls

if random_targets == 1
    cortex_ind= 1:nNeurons;
    cortex_ind(sct_ind) = [];%no target inside the scotoma
    target_ind = cortex_ind(ceil(rand(1,max_nTrials)*length(cortex_ind)));
    % hist(target_ind)
    
    if left_biased == 1
        biased_trals_ind = target_ind(1:num_biased_trials)>nNeurons/2;
        target_ind(biased_trals_ind) = target_ind(biased_trals_ind) - (nNeurons+1)/2-scotomaRad;
    elseif right_biased == 1
        biased_trals_ind = target_ind(1:num_biased_trials)<nNeurons/2;
        target_ind(biased_trals_ind) = target_ind(biased_trals_ind) + (nNeurons+1)/2+scotomaRad;        
    end
    save('data.mat', 'target_ind', 'neuron')
else
    load data.mat
end


%% acuity as a fcuntion of eccentricity from the fovea (in cortical space)
ecc_ind = 1:length(common_axis);
k = -10*log(0.8);
res = 10 * exp((k-abs(common_axis))/10);%spatial resolution (1/deg) at a cortical location ecc
%res(ecc_ind(50-scotomaRad):ecc_ind(50+scotomaRad)) = 0;%scotoma
res(ecc_ind((length(common_axis)+1)/2-scotomaRad):ecc_ind((length(common_axis)+1)/2+scotomaRad)) = 0;%scotoma
%plot(ecc_ind-(length(common_axis)+1)/2, res);xlabel('ecc from the fovea representaion(mm)');ylabel('Spatial Resolution')

% plot(ecc_ind-50, res);xlabel('ecc from the fovea representaion(mm)');ylabel('Spatial Resolution')

acu_CL = hsv(nNeurons);
trial_CL = hsv(max_nTrials);

f1 = figure(1);
set(f1, 'Position', [100, 200, 1200, 600]);%expected acuity

%% The simulation
h = figure(2);%('Position', [100, 100, 1000, 300]);
figure(3)
fprintf('**** Arrange the windows and press space when ready **** \n');
pause;
for t=1:max_nTrials
    current_tar_ind = target_ind(t);
    simulate_saccade = 0;
    %Expected acuity at the neuron's vicinity
    exp_acuity = cal_expected_acu(neuron, neuron(current_tar_ind).mean, res, common_axis, sd_m, v);
    target_physc_acu = interp1(common_axis, res, neuron(current_tar_ind).mean); %calculate the acuity TODO remove this
    
    %% expected acuity for each neuron
    exp_acuity_for_neuron = mean(exp_acuity,2);
    [best_exp_acu, best_RL_ind]  = max(exp_acuity_for_neuron);
    
    
    if target_physc_acu > best_exp_acu
        for n=1:nNeurons
            d(n) = abs(neuron(n).mean-neuron(current_tar_ind).mean);
        end
        [~, best_RL_ind] = min(d);
    else
        simulate_saccade = 1;
    end
    
    cnt(best_RL_ind) = cnt(best_RL_ind) + 1;
    
    fprintf(['trial # ', num2str(t), '.  saccade target at ',num2str(neuron(current_tar_ind).mean), '\n']);
    fprintf(['Bext acuity at x= ', num2str(neuron(best_RL_ind).mean), ...
        ', ind=', num2str(best_RL_ind),...
        ' SD= ', num2str(neuron(best_RL_ind).SD), '\n']);
    %observe the discrepancy
    dij = normrnd(0, sqrt(sd_m^2*(neuron(best_RL_ind).mean - neuron(current_tar_ind).mean)^2 + sd_e^2));
    actual_retinal_loc(t) = dij + neuron(best_RL_ind).mean;
    plot_simulated_trial;
    
    if simulate_saccade == 1
        %update the priors
    
        [new_xi_mean, new_xi_SD, new_xj_mean, new_xj_SD post_pdf] = build_grid(dij, neuron(best_RL_ind), neuron(current_tar_ind), common_axis, sd_e, sd_m);
        
        %% plot posterior
        %plot_posterior
        
        fprintf(['old mean at x=', num2str(neuron(best_RL_ind).mean), ' new mean at x= ', num2str(new_xi_mean), ...
            'old SD=', num2str(neuron(best_RL_ind).SD) ,' new SD= ', num2str(new_xi_SD), '\n']);
        
        neuron(current_tar_ind).mean = new_xj_mean;
        neuron(current_tar_ind).SD = new_xj_SD;
        
        neuron(best_RL_ind).mean = new_xi_mean;
        neuron(best_RL_ind).SD = new_xi_SD;
        
    end
    
    %%    Forgetful function
    for i = 1:nNeurons
        kap = 1/neuron(i).SD;
        kap_0 = 1/neuron(i).init_SD;
        neuron(i).SD = 1/((kap - kap_0) * exp (-1/T) + kap_0);
        neuron(i).mean = (neuron(i).mean - neuron(i).init_mean) * exp (-1/T) + neuron(i).init_mean;
    end
   % plot_priors
end
figure(1)
print('-depsc','-r300',['trials', num2str(sd_e), '_SDm' , num2str(sd_m), '.eps' ]);
figure(2)
plot_priors
print('-depsc','-r300',['priors_SDe', num2str(sd_e), '_SDm' , num2str(sd_m) '.eps']);
% saveas(h, ['priors_SDe', num2str(sd_e), '_SDm' , num2str(sd_m) ], '.fig');
%plot_distribution_changes
