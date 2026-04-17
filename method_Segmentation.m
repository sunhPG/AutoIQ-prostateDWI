%% Segmentation method
clear;
clc;
close all;

%% setup data path.
data_folder = '/Auto_IQ/dataset/data_mat/';
dir_str = dir(data_folder);

for i = 1 : length(dir_str)
    folder_name = dir_str(i).name
    close all;
   
    % set save path
    save_path = strcat(data_folder,folder_name,timepoint,'/segmentation_result/');
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

    %% label idex, find center
    tse_x = {};
    tse_y = {};
    epi_x = {};
    epi_y = {};

    tse_center = zeros(size(t2w_seg_nii,3),2);
    epi_center = zeros(size(t2w_seg_nii,3),2);


    tse_x_pol = {};
    tse_y_pol = {};
    epi_x_pol = {};
    epi_y_pol = {};

    df =zeros(size(t2w_seg_nii,3),1);

    sum_area_tse = sum(t2w_seg_nii(:));
    sum_area_epi = sum(epi_seg_nii(:));
    sum_mean = (sum_area_tse + sum_area_epi)*0.5;


    for z = 1:size(t2w_seg_nii,3)

        tse_temp = t2w_seg_nii(:,:,z);
        epi_temp = epi_seg_nii(:,:,z);

        if sum(tse_temp(:))>=1
            if sum(epi_temp(:))>=1
                b_tse_temp = bwboundaries(tse_temp);
                b_epi_temp = bwboundaries(epi_temp);

                tse_x_temp = b_tse_temp{1}(:,1);
                tse_y_temp = b_tse_temp{1}(:,2);
                epi_x_temp = b_epi_temp{1}(:,1);
                epi_y_temp = b_epi_temp{1}(:,2);

                tse_x_temp = reshape(tse_x_temp,1,[]);
                tse_y_temp = reshape(tse_y_temp,1,[]);
                epi_x_temp = reshape(epi_x_temp,1,[]);
                epi_y_temp = reshape(epi_y_temp,1,[]);

                % center
                info_tse = regionprops(tse_temp,'centroid');
                centroid_tse = round(cat(1,info_tse.Centroid));
                tse_center_temp = centroid_tse;
                tse_center(z,:) = tse_center_temp;
                tse_x_temp_centered = tse_x_temp - tse_center_temp(2);
                tse_y_temp_centered = tse_y_temp - tse_center_temp(1);

                info_epi = regionprops(epi_temp,'centroid');
                centroid_epi = round(cat(1,info_epi.Centroid));
                epi_center_temp = centroid_epi;
                epi_center(z,:) = epi_center_temp;
                epi_x_temp_centered = epi_x_temp - epi_center_temp(2);
                epi_y_temp_centered = epi_y_temp - epi_center_temp(1);

                % polar-tse
                [tse_theta,tse_rho] = cart2pol(tse_x_temp_centered,tse_y_temp_centered);
                tse_theta =round(tse_theta.*(180/pi)+180);
                [tse_theta,sortIdx] = sort(tse_theta,'ascend');
                tse_rho = tse_rho(sortIdx);
                [tse_theta_nuique,iunique] = unique(tse_theta);
                tse_rho_unique = tse_rho(iunique);

                tse_theta_new = 1:1:360;
                tse_rho_new = interp1(tse_theta_nuique,tse_rho_unique,tse_theta_new,'spline');
                tse_rho_new_smooth = smoothdata(tse_rho_new,'gaussian',5);

                % polar-epi
                [epi_theta,epi_rho] = cart2pol(epi_x_temp_centered,epi_y_temp_centered);
                epi_theta =round(epi_theta.*(180/pi)+180);
                [epi_theta,sortIdx] = sort(epi_theta,'ascend');
                epi_rho = epi_rho(sortIdx);
                [epi_theta_nuique,iunique] = unique(epi_theta);
                epi_rho_unique = epi_rho(iunique);

                epi_theta_new = 1:1:360;
                epi_rho_new = interp1(epi_theta_nuique,epi_rho_unique,epi_theta_new,'spline');
                epi_rho_new_smooth = smoothdata(epi_rho_new,'gaussian',5);


                % DF calculation for each slice
                df_rho = tse_rho_new_smooth - epi_rho_new_smooth;
                df_temp = 0;
                df_temp = (sum(df_rho.^2)/sum(tse_temp(:)))^0.5;

                df(z) = df_temp;


            end
        end
    end

    df
    
    %% mean distortion factor for each subject

    df_value = df(df>0);
    df_mean = mean(df_value(2:end-1));
    
    %% results figure generation
    figure
    plot(df_value)
    hold on
    plot([1 length(df_value)],[df_mean df_mean])
    title('Distorsion factor of each slice')
    ylabel('Df')
    xlabel('slice No.')
    xlim([1,length(df_value)])
    ax = gcf;
    exportgraphics(ax,strcat(save_path,'DF_meanplot.jpg'))

    %%
    center_dis = epi_center - tse_center;
    center_dis_flip =  tse_center -epi_center;
    idx_num = 0;
    z_list= [];
    for z = 1:size(t2w_seg_nii,3)
        tse_temp = t2w_seg_nii(:,:,z);
        epi_temp = epi_seg_nii(:,:,z);
        [tse_x_temp,tse_y_temp]= find(tse_temp == 1);
        [epi_x_temp,epi_y_temp]= find(epi_temp == 1);

        if isempty(tse_x_temp) == 0
            if isempty(epi_x_temp) == 0
                idx_num = idx_num+1;
                z_list = [z_list,z];

                tse_image_temp = t2w_nii(:,:,z);
                epi_image_temp = epi_nii(:,:,z);

                b_tse = bwboundaries(tse_temp);
                b_epi = bwboundaries(epi_temp);

                figure(z)
                subplot(1,2,1)
                imshow(tse_image_temp,[])
                %imshow(epi_image_temp,[])

                hold on
                plot(tse_center(z,1),tse_center(z,2), 'r+', 'MarkerSize', 10, 'LineWidth', 1);
                hold on
                for k = 1:length(b_tse)
                    boundary_tse = b_tse{k};
                    plot(boundary_tse(:,2),boundary_tse(:,1),'r','LineWidth',2)
                end


                %plot(epi_center(z,2)-center_dis(z,2),epi_center(z,1)-center_dis(z,1), 'g+', 'MarkerSize', 10, 'LineWidth', 1);
                hold on
                for k = 1:length(b_epi)
                    boundary_epi = b_epi{k};

                    plot(boundary_epi(:,2)-center_dis(z,1),boundary_epi(:,1)-center_dis(z,2),'g','LineWidth',1)
                end
                hold on
                title(['distortion factor = ',num2str(df(z)),' of slice ',num2str(z)])
                xlim([0,512]);
                ylim([0,512]);

                subplot(1,2,2)
                %imshow(tse_image_temp,[])
                imshow(epi_image_temp,[])

                hold on
                %plot(tse_center(z,2)-center_dis_flip(z,2),tse_center(z,1)-center_dis_flip(z,1), 'r+', 'MarkerSize', 10, 'LineWidth', 1);
                %hold on
                for k = 1:length(b_tse)
                    boundary_tse = b_tse{k};
                    plot(boundary_tse(:,2)-center_dis_flip(z,1),boundary_tse(:,1)-center_dis_flip(z,2),'r','LineWidth',2)
                end


                plot(epi_center(z,1),epi_center(z,2), 'g+', 'MarkerSize', 10, 'LineWidth', 1);
                hold on
                for k = 1:length(b_epi)
                    boundary_epi = b_epi{k};

                    plot(boundary_epi(:,2),boundary_epi(:,1),'g','LineWidth',1)
                end
                hold on
                title(['distortion factor = ',num2str(df(z)),' of slice ',num2str(z)])
                xlim([0,512]);
                ylim([0,512]);
                ax = gcf;
                exportgraphics(ax,strcat(save_path,'rigid_slice',num2str(idx_num),'_subjectslice',num2str(z),'.jpg'))

            end
        end
    end


    %%
    center_dis = epi_center - tse_center;
    center_dis_flip =  tse_center -epi_center;
    figure(1111)
    index_plot=0;
    for z = 1:size(t2w_seg_nii,3)
        tse_temp = t2w_seg_nii(:,:,z);
        epi_temp = epi_seg_nii(:,:,z);
        [tse_x_temp,tse_y_temp]= find(tse_temp == 1);
        [epi_x_temp,epi_y_temp]= find(epi_temp == 1);

        if isempty(tse_x_temp) == 0
            if isempty(epi_x_temp) == 0
                index_plot=index_plot+1;
                tse_image_temp = t2w_nii(:,:,z);
                epi_image_temp = epi_nii(:,:,z);

                b_tse = bwboundaries(tse_temp);
                b_epi = bwboundaries(epi_temp);

                subplot(6,4,index_plot)
                imshow(tse_image_temp,[])
                %imshow(epi_image_temp,[])

                hold on
                plot(tse_center(z,1),tse_center(z,2), 'r+', 'MarkerSize', 10, 'LineWidth', 1);
                hold on
                for k = 1:length(b_tse)
                    boundary_tse = b_tse{k};
                    plot(boundary_tse(:,2),boundary_tse(:,1),'r','LineWidth',2)
                end

                %plot(epi_center(z,2)-center_dis(z,2),epi_center(z,1)-center_dis(z,1), 'g+', 'MarkerSize', 10, 'LineWidth', 1);
                hold on
                for k = 1:length(b_epi)
                    boundary_epi = b_epi{k};
                    plot(boundary_epi(:,2)-center_dis(z,1),boundary_epi(:,1)-center_dis(z,2),'g','LineWidth',1)
                end
                hold on
                title(['distortion factor = ',num2str(df(z)),' of slice ',num2str(index_plot)])
                xlim([0,512]);
                ylim([0,512]);

            end
        end
    end
    
    ax = gcf;
    set(gcf,'Position',[100 100 1500 1500])
    exportgraphics(ax,strcat(save_path,'DF_all slices.jpg'))
    %% save the df info for further analysis.
    save(strcat(save_path,folder_name,'.mat'),"z_list","df_value","folder_name");
end
