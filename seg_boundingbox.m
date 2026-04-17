function [seg_boundingbox,z_list] = seg_boundingbox(t2w_seg_nii,epi_seg_nii)
z_list = [];

seg_all = t2w_seg_nii+epi_seg_nii;
seg_all(seg_all ==2 ) = 1;

for i= 1: size(t2w_seg_nii,3)
    seg_temp = seg_all(:,:,i);

    if sum(seg_temp(:))~=0  
        z_list= [z_list,i];
    end
end

seg_boundingbox = round(regionprops(seg_all,'BoundingBox').BoundingBox);

end

%get boundingbox of segmentations
%zlist is the slice that both t2w and epi has segmentations.