# SeeCAT tests

## Unit tests (synthetic data, no downloads)

```matlab
results = runtests('tests/unit');
```

Needs SPM on the path, or `SEECAT_SPM` set to the SPM folder.

## Test data

`tests/data/download_testdata.sh` downloads the public datasets used for the
end-to-end runs (about 1.6 GB) to `D:/data/SeeCAT_testdata`. Edit `ROOT` in the
script to change the location. Keep the data outside the repository.

| Dataset | Use |
|---|---|
| OpenNeuro ds000030 (UCLA CNP), 5 CONTROL + 5 SCHZ, one scanner | end-to-end pipeline, group statistics |
| OpenNeuro ds002785 (AOMIC-PIOP1), 5 subjects | multiband slice timing, fMRIPrep confounds |
| neurolabusc/dcm_qa, dcm_qa_philips | DICOM to NIfTI conversion |

All OpenNeuro data are CC0.

## Legacy baseline

`tests/legacy_baseline/run_legacy_baseline.m` drives the 1.0 GUIs headlessly:
`prep`, `fc`, `voxdeg`, `stat`. `compare_outputs.m` diffs two output trees, for
example the untouched 1.0 export against the current code.
