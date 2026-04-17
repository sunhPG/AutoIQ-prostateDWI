%% registration method
clear;
clc;
close all;
%% data path set
data_folder = '/Auto_IQ/dataset/data_mat/';
dir_str = dir(data_folder);

for i = 1 : length(dir_str)
    folder_name = dir_str(i).name
    close all;
    
    % set save path
    save_path = strcat(data_folder,folder_name,timepoint,'/registration_result/');
    mkdir(save_path);
    % t2w, dwi with corresponding mask mat files
    [t2wsfov_path,dwi_path,t2wsfov_seg_path,dwi_seg_path] = mat_data_loader(data_folder,folder_name,timepoint);
    
    % load data
    t2w_str = load(t2wsfov_path).T2;
    epi_str = load(dwi_path).ADC;
    t2w_seg_str = load(t2wsfov_seg_path).T2_mask;
    epi_seg_str = load(dwi_seg_path).ADC_mask;

    t2w_nii = permute(t2w_str,[2 3 1]);
    epi_nii = permute(epi_str,[2 3 1]);
    t2w_seg_nii = permute(t2w_seg_str,[2 3 1]);
    epi_seg_nii = permute(epi_seg_str,[2 3 1]);

    t2w_nii = single(t2w_nii);
    epi_nii = single(epi_nii);
    t2w_seg_nii = single(t2w_seg_nii);
    epi_seg_nii = single(epi_seg_nii);

    %% bounding box & zlist
    z_list= [];

    seg_all = t2w_seg_nii+epi_seg_nii;
    seg_all(seg_all ==2 ) = 1;

    for i= 1: size(t2w_seg_nii,3)
        seg_temp = seg_all(:,:,i);

        if sum(seg_temp(:))~=0  
            z_list= [z_list,i];
        end
    end

    seg_boundingbox = round(regionprops(seg_all,'BoundingBox').BoundingBox);

    z_min = min(z_list);
    z_max = max(z_list);

    %% resize and normalization
    size_buffer = 30;

    tse_resized = t2w_nii(seg_boundingbox(2)-size_buffer:seg_boundingbox(2)+seg_boundingbox(5)+size_buffer,seg_boundingbox(1)-size_buffer:seg_boundingbox(1)+seg_boundingbox(4)+20,z_min:z_max);
    epi_resized = epi_nii(seg_boundingbox(2)-size_buffer:seg_boundingbox(2)+seg_boundingbox(5)+size_buffer,seg_boundingbox(1)-size_buffer:seg_boundingbox(1)+seg_boundingbox(4)+20,z_min:z_max);

    tse_seg_resized = t2w_seg_nii(seg_boundingbox(2)-size_buffer:seg_boundingbox(2)+seg_boundingbox(5)+size_buffer,seg_boundingbox(1)-size_buffer:seg_boundingbox(1)+seg_boundingbox(4)+size_buffer,z_min:z_max);
    epi_seg_resized = epi_seg_nii(seg_boundingbox(2)-size_buffer:seg_boundingbox(2)+seg_boundingbox(5)+size_buffer,seg_boundingbox(1)-size_buffer:seg_boundingbox(1)+seg_boundingbox(4)+size_buffer,z_min:z_max);

    % normalization by 90%
    %tse_norm_factor = prctile(tse_resized(tse_resized>0),99);
    %epi_norm_factor = prctile(epi_resized(epi_resized>0),99);
    
    % normalization by mean+3std
    tse_norm_factor = mean(tse_resized(tse_resized(:)>0))+3*std(tse_resized(:)>0);
    epi_norm_factor = mean(epi_resized(epi_resized(:)>0))+3*std(epi_resized(:)>0);

    tse_pre = tse_resized/tse_norm_factor;
    epi_pre = epi_resized/epi_norm_factor;

    %% registration rigid
    epi_registered = zeros(size(tse_pre));

    [optimizer,metric] = imregconfig("multimodal");
    optimizer.InitialRadius = 0.001;
    optimizer.Epsilon = 1.5e-4;
    optimizer.GrowthFactor = 1.01;
    optimizer.MaximumIterations = 300;

    metric.NumberOfHistogramBins = 10;
    metric.NumberOfSpatialSamples = 200;
    
    translation_matrix = [];

    for i = 1:size(tse_pre,3)
        tse_temp = tse_pre(:,:,i);
        epi_temp = epi_pre(:,:,i);

        %tse_temp_for_r = imadjust(tse_temp,[mean(tse_temp(tse_temp>0))-0.4*std(tse_temp(tse_temp>0)) mean(tse_temp(tse_temp>0))+0.4*std(tse_temp(tse_temp>0))],[]);
        %epi_temp_for_r = imadjust(epi_temp,[mean(epi_temp(epi_temp>0))-0.5*std(epi_temp(epi_temp>0)) mean(epi_temp(epi_temp>0))+0.5*std(epi_temp(epi_temp>0))],[]);

        tse_temp_for_r = tse_temp;
        epi_temp_for_r = epi_temp;

        %[epi_registered_temp,reg_rigid] = imregister(epi_temp_for_r,tse_temp_for_r,'rigid',optimizer,metric);
        tform_temp = imregtform(epi_temp_for_r,tse_temp_for_r,'rigid',optimizer,metric);
        epi_registered_temp = imwarp(epi_temp_for_r,tform_temp,"OutputView",imref2d(size(tse_temp_for_r)));
        translation_matrix = [translation_matrix;tform_temp.Translation];
        epi_registered(:,:,i) = epi_registered_temp;

        % imshow chekcing
        figure(i)
        subplot(1,3,1)
        imshow(tse_temp_for_r,[])
        subtitle('tse_orig')

        subplot(1,3,2)
        imshow(epi_temp_for_r,[])
        subtitle('epi_orig')

        subplot(1,3,3)
        imshow(epi_registered_temp,[])
        subtitle('epi_registered')
        ax = gcf;
        exportgraphics(ax,strcat(save_path,'rigid_slice',num2str(i),'_subjectslice',num2str(z_list(i)),'.jpg'))

    end

    %% registraion deformable

    distortion_factor = [];
    distrotion_factor_transadded = [];

    size(epi_registered)
    tse_resized_for_deform = tse_pre( 10:end-10,10:end-10 ,:);
    epi_resized_for_deform = epi_registered( 10:end-10,10:end-10 ,:);

    tse_seg_for_deform = tse_seg_resized( 10:end-10,10:end-10 ,:);
    epi_seg_for_deform = epi_seg_resized( 10:end-10,10:end-10 ,:);

    size(epi_resized_for_deform)

    epi_registered_deformable_dispField = zeros(size(tse_resized_for_deform));
    epi_registered_deformable_reg = zeros(size(tse_resized_for_deform,1),size(tse_resized_for_deform,2),size(tse_resized_for_deform,3),2);

    for i = 1: size(epi_resized_for_deform,3)

        tse_seg_for_deform_temp = tse_seg_for_deform(:,:,i);
        b_tse = bwboundaries(tse_seg_for_deform_temp);

        tse_seg_for_deform_temp = tse_seg_for_deform_temp(:);

        tse_temp = tse_resized_for_deform(:,:,i);
        epi_temp = epi_resized_for_deform(:,:,i);

        [dispField,reg] = imregdeform(epi_temp,tse_temp,NumPyramidLevels=6,GridRegularization=0.2);
        epi_registered_deformable_dispField(:,:,i,1) = dispField(:,:,1);
        epi_registered_deformable_dispField(:,:,i,2) = dispField(:,:,2);
        epi_registered_deformable_reg(:,:,i) = reg;

        % distortion factor calculation

        dispField_x = dispField(:,:,1);
        dispField_y = dispField(:,:,2);
        dispField_x = dispField_x(:);
        dispField_y = dispField_y(:);

        dispField_x_rigid_trans = ones(size(dispField_x))*translation_matrix(i,1);
        dispField_y_rigid_trans = ones(size(dispField_y))*translation_matrix(i,1);
        
        % dis_factor based on deformable registration;
        % distrotion_factor_transadded based on rigid + deformable.
        dis_factor_temp = sqrt(sum(dispField_x(tse_seg_for_deform_temp==1).^2+dispField_y(tse_seg_for_deform_temp==1).^2)/sum(tse_seg_for_deform_temp));
        distrotion_factor_transadded_temp =  sqrt(sum((dispField_x(tse_seg_for_deform_temp==1)+dispField_x_rigid_trans(tse_seg_for_deform_temp==1)).^2+(dispField_y(tse_seg_for_deform_temp==1)+dispField_y_rigid_trans(tse_seg_for_deform_temp==1)).^2)/sum(tse_seg_for_deform_temp));
    
        distortion_factor = [distortion_factor,dis_factor_temp];
        distrotion_factor_transadded = [distrotion_factor_transadded,distrotion_factor_transadded_temp];

        figure(i+100)
        subplot(1,3,1)
        imshow(tse_temp,[])
        hold on
        for k = 1:length(b_tse)
            boundary_tse = b_tse{k};
            plot(boundary_tse(:,2),boundary_tse(:,1),'r','LineStyle',':','LineWidth',1.5)
        end

        subplot(1,3,2)
        imshow(epi_temp,[])
        hold on
        for k = 1:length(b_tse)
            boundary_tse = b_tse{k};
            plot(boundary_tse(:,2),boundary_tse(:,1),'r','LineStyle',':','LineWidth',1.5)
        end

        subplot(1,3,3)
        imshow(reg,[])
        hold on
        for k = 1:length(b_tse)
            boundary_tse = b_tse{k};
            plot(boundary_tse(:,2),boundary_tse(:,1),'r','LineStyle',':','LineWidth',1.5)
        end
        title(['DF = ',num2str(dis_factor_temp),'of slice',num2str(i)])

        ax = gcf;
        exportgraphics(ax,strcat(save_path,'slice',num2str(i),'_subjectslice',num2str(z_list(i)),'.jpg'))

    end

    %%  distortion factor plot
    df_mean = mean(distortion_factor(3:end-2));
    figure(1000)
    plot(distortion_factor)
    hold on
    plot([1 length(distortion_factor)],[df_mean df_mean])
    title(['Distorsion factor of each slice (mean Df=',num2str(df_mean),')'])
    ylabel('Df')
    xlabel('slice No.')
    xlim([1,length(distortion_factor)])
    ylim([0,15])

    ax = gcf;
    exportgraphics(ax,strcat(save_path,'DF_meanplot.jpg'))

    %% save the df info for further analysis.
    save(strcat(save_path,folder_name,'.mat'),"z_list","distortion_factor","folder_name","distrotion_factor_transadded");

end