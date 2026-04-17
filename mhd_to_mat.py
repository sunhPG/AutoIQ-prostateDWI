import os
import glob
import SimpleITK as sitk
import scipy.io

def convert_mhd_to_mat(file_path, save_path):
    os.makedirs(save_path, exist_ok=True)
    subject_list = os.listdir(file_path)

    for i, subject in enumerate(subject_list):
        print('Processing subject {}/{}: {}_{}'.format(i+1, len(subject_list), subject))

        # Construct the file path pattern.
        t2_file_pattern = os.path.join(file_path, subject, '*', '*', '*', 'T2_axial.mhd')
        adc_file_pattern = os.path.join(file_path, subject, '*', '*', '*', 'DWI_ADC.mhd')
        t2_mask_file_pattern = os.path.join(file_path, subject, '*', '*', '*', 'Mask.mhd')
        adc_mask_file_pattern = os.path.join(file_path, subject, '*', '*', '*', 'Mask_B0.mhd')

        t2_files_path = glob.glob(t2_file_pattern)
        adc_files_path = glob.glob(adc_file_pattern)
        t2_mask_files_path = glob.glob(t2_mask_file_pattern)
        adc_mask_files_path = glob.glob(adc_mask_file_pattern)

        # Read and process images and masks.
        t2_mhd = sitk.ReadImage(t2_files_path[0])
        t2_array = sitk.GetArrayFromImage(t2_mhd)
        t2_mask_mhd = sitk.ReadImage(t2_mask_files_path[0])
        t2_mask_array = sitk.GetArrayFromImage(t2_mask_mhd)
        t2_mask_array[t2_mask_array > 0] = 1

        adc_mhd = sitk.ReadImage(adc_files_path[0])
        adc_array = sitk.GetArrayFromImage(adc_mhd)
        adc_mask_mhd = sitk.ReadImage(adc_mask_files_path[0])
        adc_mask_array = sitk.GetArrayFromImage(adc_mask_mhd)
        adc_mask_array[adc_mask_array > 0] = 1

        print('T2 image shape: {}'.format(t2_array.shape))
        print('T2 mask shape: {}'.format(t2_mask_array.shape))
        print('ADC image shape: {}'.format(adc_array.shape))
        print('ADC mask shape: {}'.format(adc_mask_array.shape))

        # Save the image and mask as mat files
        save_path_subject = os.path.join(save_path, subject, 'mat')
        os.makedirs(save_path_subject, exist_ok=True)
        scipy.io.savemat(os.path.join(save_path_subject, 'T2.mat'), {'T2': t2_array})
        scipy.io.savemat(os.path.join(save_path_subject, 'T2_mask.mat'), {'T2_mask': t2_mask_array})
        scipy.io.savemat(os.path.join(save_path_subject, 'ADC.mat'), {'ADC': adc_array})
        scipy.io.savemat(os.path.join(save_path_subject, 'ADC_mask.mat'), {'ADC_mask': adc_mask_array})

# Example usage
if __name__ == '__main__':
    file_path = '/Auto_IQ/dataset/data_mhd/'
    save_path = '/Auto_IQ/dataset/data_mat/'
    convert_mhd_to_mat(file_path, save_path)