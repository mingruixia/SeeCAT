#!/bin/bash
# Download public test data for SeeCAT redevelopment
set -u
ROOT="D:/data/SeeCAT_testdata"
S3="https://s3.amazonaws.com/openneuro.org"
get(){ # url dest
  mkdir -p "$(dirname "$2")"
  [ -s "$2" ] && return 0
  curl -sSf -m 1800 --retry 3 "$1" -o "$2" || echo "FAILED $1"
}
# ds000030: 5 CONTROL + 5 SCHZ, scanner 35426, No_ghost
D=$ROOT/ds000030
for f in dataset_description.json participants.tsv task-rest_bold.json README CHANGES; do get "$S3/ds000030/$f" "$D/$f"; done
for s in sub-11061 sub-11062 sub-11066 sub-11067 sub-11068 sub-50047 sub-50048 sub-50050 sub-50052 sub-50056; do
  get "$S3/ds000030/$s/anat/${s}_T1w.nii.gz" "$D/$s/anat/${s}_T1w.nii.gz"
  get "$S3/ds000030/$s/anat/${s}_T1w.json" "$D/$s/anat/${s}_T1w.json"
  get "$S3/ds000030/$s/func/${s}_task-rest_bold.nii.gz" "$D/$s/func/${s}_task-rest_bold.nii.gz"
  get "$S3/ds000030/$s/func/${s}_task-rest_bold.json" "$D/$s/func/${s}_task-rest_bold.json"
done
# ds002785 AOMIC-PIOP1: 5 subjects, multiband rest + T1w + fMRIPrep confounds
D=$ROOT/ds002785
for f in dataset_description.json participants.tsv task-restingstate_acq-mb3_bold.json README CHANGES; do get "$S3/ds002785/$f" "$D/$f"; done
for s in sub-0001 sub-0002 sub-0003 sub-0004 sub-0005; do
  get "$S3/ds002785/$s/anat/${s}_T1w.nii.gz" "$D/$s/anat/${s}_T1w.nii.gz"
  get "$S3/ds002785/$s/func/${s}_task-restingstate_acq-mb3_bold.nii.gz" "$D/$s/func/${s}_task-restingstate_acq-mb3_bold.nii.gz"
  get "$S3/ds002785/$s/func/${s}_task-restingstate_acq-mb3_bold.json" "$D/$s/func/${s}_task-restingstate_acq-mb3_bold.json"
  get "$S3/ds002785/derivatives/fmriprep/$s/func/${s}_task-restingstate_acq-mb3_desc-confounds_regressors.tsv" "$D/derivatives/fmriprep/$s/func/${s}_task-restingstate_acq-mb3_desc-confounds_regressors.tsv"
done
# DICOM conversion validation sets
mkdir -p "$ROOT/dicom"
for r in dcm_qa dcm_qa_philips; do
  [ -d "$ROOT/dicom/$r" ] || git clone -q --depth 1 "https://github.com/neurolabusc/$r.git" "$ROOT/dicom/$r" || echo "FAILED clone $r"
done
echo DONE; du -sh "$ROOT"/*
