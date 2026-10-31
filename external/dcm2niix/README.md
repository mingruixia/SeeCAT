# dcm2niix (bundled in releases)

SeeCAT releases include dcm2niix for Windows, macOS and Linux in
`external/dcm2niix/<win|mac|lnx>/`. The binaries are not kept in git; the
release script puts them here. `seecat.util.find_dcm2niix` looks here after
`SEECAT_DCM2NIIX` and before the system PATH.

- Version: v1.0.20260724 (released 2026-07-24)
- Source: https://github.com/rordenlab/dcm2niix/releases/tag/v1.0.20260724
- `dcm2niix_win.zip`: 1,196,271 bytes, SHA-256
  `8310549ef7340b1b169c26f4721aeac69423fd73643fbbd22eec47b36cc70ada`
  (the Windows zip also holds the Microsoft C++ runtime DLLs it needs)
- Licence: to be copied from the dcm2niix repository into
  `THIRD_PARTY_NOTICES` at release time.

Tested with the dcm2niix QA data (`dcm_qa`, `dcm_qa_philips`):
`tests/unit/test_dicom.m`.
