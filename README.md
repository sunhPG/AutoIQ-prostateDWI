# AutoIQ Source Code README

## Overview

This repository contains the core source files for the **AutoIQ** prostate MRI distortion-assessment pipeline.  
At a high level, the workflow is:

1. **Convert raw `.mhd` images and masks into `.mat` files**
2. **Load paired T2-weighted and ADC volumes plus masks**
3. **Extract prostate-containing slices and a bounding box around the gland**
4. **Run slice-wise rigid + deformable registration between ADC and T2**
5. **Compute registration-based distortion factors**
6. **Build downstream machine-learning models for scan-quality classification**

The uploaded source files mainly cover the **preprocessing / registration pipeline** and the **model development notebook**.

---

## Files

### 1. `mhd_to_mat.py`
Converts raw image files from `.mhd` format into MATLAB `.mat` files for downstream processing.

**Main responsibilities**
- Iterates through subject folders
- Locates:
  - `T2_axial.mhd`
  - `DWI_ADC.mhd`
  - `Mask.mhd`
  - `Mask_B0.mhd`
- Reads images and masks using **SimpleITK**
- Converts masks to binary
- Saves outputs as:
  - `T2.mat`
  - `T2_mask.mat`
  - `ADC.mat`
  - `ADC_mask.mat`

**Expected input structure**
```text
/Auto_IQ/dataset/data_mhd/
└── <subject>/
    └── .../.../.../
        ├── T2_axial.mhd
        ├── DWI_ADC.mhd
        ├── Mask.mhd
        └── Mask_B0.mhd
```

**Output structure**
```text
/Auto_IQ/dataset/data_mat/
└── <subject>/
    └── mat/
        ├── T2.mat
        ├── T2_mask.mat
        ├── ADC.mat
        └── ADC_mask.mat
```

**Dependencies**
- Python 3
- `SimpleITK`
- `scipy`
- `glob`
- `os`

Run example:
```bash
python mhd_to_mat.py
```

---

### 2. `mat_data_loader.m`
A small MATLAB helper function that constructs file paths for the converted `.mat` files.

**Function**
```matlab
[t2wsfov_path,dwi_path,t2wsfov_seg_path,dwi_seg_path] = mat_data_loader(data_folder, folder_name)
```

**Returns**
- Path to `T2.mat`
- Path to `ADC.mat`
- Path to `T2_mask.mat`
- Path to `ADC_mask.mat`

This function is used as a simple path utility inside the registration pipeline.

---

### 3. `seg_boundingbox.m`
Computes:
- the slice indices that contain prostate segmentation (`z_list`)
- a 3D bounding box around the union of T2 and EPI/ADC masks

**Function**
```matlab
[seg_boundingbox, z_list] = seg_boundingbox(t2w_seg_nii, epi_seg_nii)
```

**What it does**
- Combines the two masks
- Finds slices with non-zero segmentation
- Uses `regionprops(..., 'BoundingBox')` to define a crop region

This is useful for focusing registration and distortion analysis on the relevant anatomy instead of the full field of view.

---

### 4. `method_Registration.m`
Main MATLAB script for **registration-based distortion quantification**.

## Pipeline summary

For each subject, the script:

1. Loads T2, ADC, and their masks from `.mat`
2. Permutes arrays into MATLAB-friendly orientation
3. Finds the segmented slices and bounding box
4. Crops around the prostate region
5. Normalizes intensity
6. Runs **slice-wise rigid registration**
7. Runs **slice-wise deformable registration**
8. Computes distortion-factor metrics from the deformation field
9. Saves visualizations and a `.mat` result file

### Registration stages

#### A. Rigid registration
Uses:
- `imregtform`
- `imwarp`
- multimodal registration settings from `imregconfig("multimodal")`

The rigid stage estimates slice-wise translation/alignment between ADC and T2.

#### B. Deformable registration
Uses:
- `imregdeform`

The deformable stage estimates a displacement field between registered ADC and T2 for each slice.

### Distortion factor
The script computes distortion metrics from the displacement field inside the prostate mask.  
It stores:
- `distortion_factor`
- `distrotion_factor_transadded`

These values can later be used as features for scan-quality classification.

### Saved outputs
Per subject, the script exports:
- rigid-registration check images
- deformable-registration check images
- distortion-factor plot
- `.mat` file containing the distortion metrics and slice list

---

### 5. `model_development.ipynb`
Notebook for downstream machine-learning model development.

## What it appears to do
The notebook is organized into sections for:
- **segmentation-based model**
- **registration-based model**
- **direct combined model**
- **ensemble model**
- **calibration and decision-curve analysis**

## Likely inputs
The notebook expects training and test CSV files containing at least:
- `seg_value`
- `reg_value`
- `rank`

These are used to train classical ML models such as:
- Logistic Regression
- SVM
- Random Forest
- Gradient Boosting
- KNN
- Gaussian Naive Bayes

It also includes:
- cross-validation
- ROC / AUC evaluation
- calibration analysis
- decision-curve style post-analysis

## Note
The current notebook has placeholder-like path strings (for example empty `data_path` / CSV file paths), so it should be treated as a development notebook that requires local path editing before execution.

---

## End-to-end workflow

A typical workflow is:

### Step 1 — Convert raw data
Run:
```bash
python mhd_to_mat.py
```

### Step 2 — Run MATLAB registration analysis
Run:
```matlab
method_Registration
```

This produces per-subject distortion metrics and QA figures.

### Step 3 — Prepare tabular features
Aggregate the outputs from:
- segmentation-based distortion quantification
- registration-based distortion quantification

into CSV files for training / testing.

### Step 4 — Train classification models
Open and run:
```text
model_development.ipynb
```

This step builds the final scan-quality classifier(s), including ensemble and calibration analysis.

---

## Suggested directory layout

```text
Auto_IQ/
├── dataset/
│   ├── data_mhd/
│   │   └── <subject folders with raw .mhd files>
│   └── data_mat/
│       └── <subject>/
│           ├── mat/
│           │   ├── T2.mat
│           │   ├── T2_mask.mat
│           │   ├── ADC.mat
│           │   └── ADC_mask.mat
│           └── registration_result/
├── src/
│   ├── mhd_to_mat.py
│   ├── mat_data_loader.m
│   ├── seg_boundingbox.m
│   └── method_Registration.m
└── notebooks/
    └── model_development.ipynb
```

---

## Dependencies

### Python
- Python 3.x
- `SimpleITK`
- `scipy`
- `numpy`
- `pandas`
- `matplotlib`
- `scikit-learn`

Install example:
```bash
pip install SimpleITK scipy numpy pandas matplotlib scikit-learn
```

### MATLAB
Required toolboxes/functions likely include:
- Image Processing Toolbox
- functions such as:
  - `regionprops`
  - `imregtform`
  - `imwarp`
  - `imregdeform`
  - `bwboundaries`
  - `exportgraphics`

---

## Known issues / things to check

### 1. `mat_data_loader.m` vs `method_Registration.m`
The uploaded `mat_data_loader.m` accepts:
```matlab
mat_data_loader(data_folder, folder_name)
```

But `method_Registration.m` calls:
```matlab
mat_data_loader(data_folder,folder_name,timepoint)
```

This suggests one of the following:
- there is another version of `mat_data_loader.m`
- `timepoint` support was added in the script but not in the helper
- the current uploaded files are from slightly different code revisions

### 2. `timepoint` appears undefined in `method_Registration.m`
The script uses:
```matlab
save_path = strcat(data_folder,folder_name,timepoint,'/registration_result/');
```
but the uploaded script does not define `timepoint` beforehand.

This should be fixed before running the script directly.

### 3. Potential indexing mismatch in rigid translation
In the deformable-registration section:
```matlab
dispField_y_rigid_trans = ones(size(dispField_y))*translation_matrix(i,1);
```
It may be intended to use the **second** translation component for Y:
```matlab
translation_matrix(i,2)
```
This is worth verifying.

### 4. Subject-folder iteration
`dir(data_folder)` in MATLAB also returns `.` and `..`, so filtering valid subject folders may be necessary before processing.

### 5. Bounding-box safety
Cropping with margins such as `size_buffer = 30` can fail if the bounding box is too close to an image boundary. Boundary checking may be needed.

---

## Recommended next cleanup steps

- Move all scripts into a dedicated `src/` folder
- Add a config file for data paths
- Unify naming (`dwi` vs `adc`, `tse` vs `t2w`)
- Add subject filtering to skip invalid folders
- Refactor `method_Registration.m` into functions:
  - data loading
  - crop extraction
  - normalization
  - rigid registration
  - deformable registration
  - metric computation
- Export final tabular distortion features automatically for notebook use

---


