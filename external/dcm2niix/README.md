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
- `dcm2niix_mac.zip`: 930,002 bytes, SHA-256
  `d393006dd1edfba4013bc4b8eccc875b23d611ecbc53fda5a5542f629591008f`
- `dcm2niix_lnx.zip`: 947,680 bytes, SHA-256
  `2916a7bc64511eb20fb976a994799183cc1bfdd03395bf5d8edef54a58dee06f`
- Licence: BSD 2-clause, reproduced in `THIRD_PARTY_NOTICES`.

`tools/make_release.m` checks each zip's size and SHA-256 against these
values (and the GitHub release's asset digests) before unpacking it. MATLAB
zips do not keep the executable bit, so `find_dcm2niix` sets it on the
bundled macOS/Linux binary.

Tested with the dcm2niix QA data (`dcm_qa`, `dcm_qa_philips`):
`tests/unit/test_dicom.m`.

The Linux binary needs glibc 2.29 or later (it fails on Ubuntu 18.04 and
RHEL 8); `find_dcm2niix` then falls back to a dcm2niix on the PATH.
