function [t2wsfov_path,dwi_path,t2wsfov_seg_path,dwi_seg_path] = mat_data_loader(data_folder,folder_name)

t2wsfov_path = strcat(data_folder,folder_name,'/mat/', 'T2.mat');
dwi_path = strcat(data_folder,folder_name,'/mat/', 'ADC.mat');

t2wsfov_seg_path = strcat(data_folder,folder_name,'/mat/', 'T2_mask.mat');
dwi_seg_path = strcat(data_folder,folder_name,'/mat/', 'ADC_mask.mat');

end
