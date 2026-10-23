# Superfície AGC / VideoOut / Ampr importada pelo eboot

> Gerado por `tools/nid_db.py`. Escopo da Fase 4 (PLAN.md §6).

| Biblioteca | implemented | stub | missing | total | sítios de chamada |
|---|---:|---:|---:|---:|---:|
| libSceAgc | 133 | 1 | 77 | 211 | 220 |
| libSceAgcDriver | 20 | 1 | 23 | 44 | 47 |
| libSceVideoOut | 14 | 0 | 0 | 14 | 29 |
| libSceAmpr | 59 | 1 | 0 | 60 | 88 |

## libSceAgc

| NID | Nome verificado | Status | Função no engine | Biblioteca na HLE | Sítios |
|---|---|---|---|---|---:|
| `RmaJwLtc8rY` | sceAgcDcbSetBaseIndirectArgs | `implemented` | Gen5::AgcDcbSetBaseIndirectArgs | Graphics5 | 3 |
| `aJf+j5yntiU` | sceAgcDcbEventWrite | `implemented` | Gen5::AgcDcbEventWrite | Graphics5 | 3 |
| `bbFueFP+J4k` | sceAgcDcbSetPredication | `implemented` | Gen5::AgcDcbSetPredication | Graphics5 | 3 |
| `wr23dPKyWc0` | sceAgcCbReleaseMem | `implemented` | Gen5::AgcCbReleaseMem | Graphics5 | 3 |
| `7Wa3aeJgeVU` |  | `implemented` | Gen5::AgcBranchPatchSetThenTarget | Graphics5 | 2 |
| `7nOoijNPvEU` | sceAgcWaitRegMemPatchReference | `implemented` | Gen5::AgcWaitRegMemPatchReference | Graphics5 | 2 |
| `Ikfdt-rIqCE` |  | `implemented` | Gen5::AgcJumpPatchSetTarget_0300 | Graphics5 | 2 |
| `LFSPFmGc9Hg` | sceAgcDcbSetWorkloadsActive | `implemented` | Gen5::AgcDcbSetWorkloadsActive | Graphics5 | 2 |
| `V++UgBtQhn0` |  | `implemented` | Gen5::AgcGetDataPacketPayloadAddress | Graphics5 | 2 |
| `i1jyy49AjXU` | sceAgcDcbWriteData | `implemented` | Gen5::AgcDcbWriteData | Graphics5 | 2 |
| `uZW-mqsxkrM` | sceAgcCbBranchGetSize | `implemented` | Gen5::AgcCbBranchGetSize | Graphics5 | 2 |
| `vuSXe69VILM` | sceAgcDcbGetLodStats | `implemented` | Gen5::AgcDcbGetLodStats | Graphics5 | 2 |
| `w1KFAHVqpaU` | sceAgcCbBranch | `implemented` | Gen5::AgcCbBranch | Graphics5 | 2 |
| `+kSrjIVxKFE` | sceAgcDcbPushMarker | `implemented` | Gen5::AgcDcbPushMarker | Graphics5 | 1 |
| `-HOOCn0JY48` | sceAgcDcbSetShRegistersIndirect | `implemented` | Gen5::AgcDcbSetShRegistersIndirect | Graphics5 | 1 |
| `-KRzWekV120` |  | `implemented` | Gen5::AgcDcbSetIndexSize_0600 | Graphics5 | 1 |
| `-RnpfpxIhec` | sceAgcAcbDmaData | `implemented` | Gen5::AgcAcbDmaData | Graphics5 | 1 |
| `-vnlTPPXPrw` | sceAgcDcbAcquireMemGetSize | `implemented` | Gen5::AgcDcbAcquireMemGetSize | Graphics5 | 1 |
| `03RZmELWWzw` | sceAgcCbSetUcRegistersDirect | `implemented` | Gen5::AgcCbSetUcRegistersDirect | Graphics5 | 1 |
| `0fWWK5uG9rQ` | sceAgcQueueEndOfPipeActionPatchAddress | `implemented` | Gen5::AgcQueueEndOfPipeActionPatchAddress | Graphics5 | 1 |
| `1DeUNpRIDDA` | sceAgcDcbSetCxRegisterDirectGetSize | `implemented` | Gen5::AgcDcbSetCxRegisterDirectGetSize | Graphics5 | 1 |
| `1rZSWUv1IRc` | sceAgcDcbCopyData | `implemented` | Gen5::AgcDcbCopyData | Graphics5 | 1 |
| `23LRUSvYu1M` |  | `implemented` | Gen5::AgcInit | Graphics5 | 1 |
| `2JtWUUiYBXs` | sceAgcGetRegisterDefaults2 | `implemented` | Gen5::AgcGetRegisterDefaults2 | Graphics5 | 1 |
| `3KDcnM3lrcU` | sceAgcWaitRegMemPatchAddress | `implemented` | Gen5::AgcWaitRegMemPatchAddress | Graphics5 | 1 |
| `3ZWa3AoyWZQ` |  | `implemented` | Gen5::AgcCondExecPatchSetCommandAddress | Graphics5 | 1 |
| `43WJ08sSugE` | sceAgcDcbWaitOnAddressGetSize | `implemented` | Gen5::AgcDcbWaitOnAddressGetSize | Graphics5 | 1 |
| `57labkp+rSQ` | sceAgcDcbAcquireMem | `implemented` | Gen5::AgcDcbAcquireMem | Graphics5 | 1 |
| `6DFuRKT4C9w` | sceAgcDcbSetNumInstancesGetSize | `implemented` | Gen5::AgcDcbSetNumInstancesGetSize | Graphics5 | 1 |
| `6ee9Hd3EWXQ` | sceAgcDcbDrawIndexGetSize | `implemented` | Gen5::AgcDcbDrawIndexGetSize | Graphics5 | 1 |
| `6lNcCp+fxi4` | sceAgcSetUcRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetUcRegIndirectPatchSetAddress | Graphics5 | 1 |
| `6mFxkVqdmbQ` | sceAgcAcbPopMarker | `implemented` | Gen5::AgcAcbPopMarker | Graphics5 | 1 |
| `8N2tmT3jmC8` | sceAgcDcbSetIndexCount | `implemented` | Gen5::AgcDcbSetIndexCount | Graphics5 | 1 |
| `Abendgtz+3o` | sceAgcCbDispatchGetSize | `implemented` | Gen5::AgcCbDispatchGetSize | Graphics5 | 1 |
| `BIPexNBSGog` | sceAgcDcbCondExec | `implemented` | Gen5::AgcDcbCondExec | Graphics5 | 1 |
| `BfBDZGbti7A` | sceAgcGetIsTrinityMode | `implemented` | Gen5::AgcGetIsTrinityMode | Graphics5 | 1 |
| `C4l9fB17t8w` | sceAgcDcbEventWriteGetSize | `implemented` | Gen5::AgcDcbEventWriteGetSize | Graphics5 | 1 |
| `CbQh3DKMSno` | sceAgcAcbCopyDataGetSize | `implemented` | Gen5::AgcAcbCopyDataGetSize | Graphics5 | 1 |
| `DwICrVxerkY` | sceAgcAcbRewind | `implemented` | Gen5::AgcAcbRewind | Graphics5 | 1 |
| `GBCh3zCihoU` | sceAgcDcbSetCxRegistersIndirectGetSize | `implemented` | Gen5::AgcDcbSetCxRegistersIndirectGetSize | Graphics5 | 1 |
| `H6vHS5cidSA` | sceAgcDcbContextStateOpGetSize | `implemented` | Gen5::AgcDcbContextStateOpGetSize | Graphics5 | 1 |
| `H7uZqCoNuWk` | sceAgcDcbPopMarker | `implemented` | Gen5::AgcDcbPopMarker | Graphics5 | 1 |
| `IxYiarKlXxM` | sceAgcDmaDataPatchSetDstAddressOrOffset | `implemented` | Gen5::AgcDmaDataPatchSetDstAddressOrOffset | Graphics5 | 1 |
| `JrtiDtKeS38` | sceAgcAcbResetQueue | `implemented` | Gen5::AgcAcbResetQueue | Graphics5 | 1 |
| `K2mciNVxUCE` | sceAgcSetNop | `implemented` | Gen5::AgcSetNop | Graphics5 | 1 |
| `KT-hTp-Ch14` | sceAgcAcbAcquireMem | `implemented` | Gen5::AgcAcbAcquireMem | Graphics5 | 1 |
| `LHFXRrlTPD8` | sceAgcDcbSetCxRegisterDirect | `implemented` | Gen5::AgcDcbSetCxRegisterDirect | Graphics5 | 1 |
| `Lkf86B98qPc` | sceAgcGetPacketSize | `implemented` | Gen5::AgcGetPacketSize | Graphics5 | 1 |
| `LtTouSCZjHM` | sceAgcCbNop | `implemented` | Gen5::AgcCbNop | Graphics5 | 1 |
| `MWiElSNE8j8` | sceAgcDcbWaitUntilSafeForRendering | `implemented` | Gen5::AgcDcbWaitUntilSafeForRendering | Graphics5 | 1 |
| `MlEw1feXcjg` | sceAgcQueueEndOfPipeActionPatchData | `implemented` | Gen5::AgcQueueEndOfPipeActionPatchData | Graphics5 | 1 |
| `ORWsxIbk4TE` | sceAgcCondExecPatchSetEnd | `implemented` | Gen5::AgcCondExecPatchSetEnd | Graphics5 | 1 |
| `QIXCsbipds0` | sceAgcDcbRewindGetSize | `implemented` | Gen5::AgcDcbRewindGetSize | Graphics5 | 1 |
| `QhCbS4X9Rl8` | sceAgcDcbSetMarker | `implemented` | Gen5::AgcDcbSetMarker | Graphics5 | 1 |
| `Qrj4c+61z4A` | sceAgcSetShRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetShRegIndirectPatchSetAddress | Graphics5 | 1 |
| `TRO721eVt4g` | sceAgcDcbResetQueue | `implemented` | Gen5::AgcDcbResetQueue | Graphics5 | 1 |
| `UZbQjYAwwXM` | sceAgcCbSetShRegistersDirect | `implemented` | Gen5::AgcCbSetShRegistersDirect | Graphics5 | 1 |
| `VEGu4dixjUg` | sceAgcDcbJumpGetSize | `implemented` | Gen5::AgcDcbJumpGetSize | Graphics5 | 1 |
| `VmW0Tdpy420` | sceAgcDcbWaitRegMem | `implemented` | Gen5::AgcDcbWaitRegMem | Graphics5 | 1 |
| `WmAc2MEj6Io` | sceAgcDcbDmaData | `implemented` | Gen5::AgcDcbDmaData | Graphics5 | 1 |
| `WrdP9Zxx3lQ` | sceAgcDcbDrawIndexAutoGetSize | `implemented` | Gen5::AgcDcbDrawIndexAutoGetSize | Graphics5 | 1 |
| `Y3ymLfZ1384` | sceAgcUpdatePrimState | `implemented` | Gen5::AgcUpdatePrimState | Graphics5 | 1 |
| `YUeqkyT7mEQ` | sceAgcDcbSetFlip | `implemented` | Gen5::AgcDcbSetFlip | Graphics5 | 1 |
| `YWTKOju587o` | sceAgcCondExecPatchSetCommandAddress | `implemented` | Gen5::AgcCondExecPatchSetCommandAddress | Graphics5 | 1 |
| `ZvwO9euwYzc` | sceAgcDcbSetCxRegistersIndirect | `implemented` | Gen5::AgcDcbSetCxRegistersIndirect | Graphics5 | 1 |
| `b-oySn+G2tE` | sceAgcAcbJumpGetSize | `implemented` | Gen5::AgcAcbJumpGetSize | Graphics5 | 1 |
| `b5u0Jzm8TF8` | sceAgcDcbCopyDataGetSize | `implemented` | Gen5::AgcDcbCopyDataGetSize | Graphics5 | 1 |
| `bxGoVxpdSPQ` | sceAgcCbSetShRegisterRangeDirectGetSize | `implemented` | Gen5::AgcCbSetShRegisterRangeDirectGetSize | Graphics5 | 1 |
| `cFazmnXpJOE` | sceAgcAcbEventWrite | `implemented` | Gen5::AgcAcbEventWrite | Graphics5 | 1 |
| `cdDRpqcFGbU` | sceAgcDmaDataPatchSetSrcAddressOrOffsetOrImmediate | `implemented` | Gen5::AgcDmaDataPatchSetSrcAddressOrOffsetOrImmediate | Graphics5 | 1 |
| `cpCILPya5Zk` | sceAgcAcbPushMarker | `implemented` | Gen5::AgcAcbPushMarker | Graphics5 | 1 |
| `cxPZ4Wgvdj8` | sceAgcDcbDrawIndirectGetSize | `implemented` | Gen5::AgcDcbDrawIndirectGetSize | Graphics5 | 1 |
| `d-6uF9sZDIU` | sceAgcSetCxRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetCxRegIndirectPatchAddRegisters | Graphics5 | 1 |
| `e1DFTg+Sd8U` | sceAgcAcbJump | `implemented` | Gen5::AgcAcbJump | Graphics5 | 1 |
| `eWaWyFegzgQ` |  | `implemented` | Gen5::AgcRewindPatchSetRewindState | Graphics5 | 1 |
| `eZ4+17OQz4Q` | sceAgcAcbWriteData | `implemented` | Gen5::AgcAcbWriteData | Graphics5 | 1 |
| `ewobAQeMo5k` | sceAgcAcbAcquireMemGetSize | `implemented` | Gen5::AgcAcbAcquireMemGetSize | Graphics5 | 1 |
| `fPSCdQxgpSw` | sceAgcWriteDataPatchSetAddressOrOffset | `implemented` | Gen5::AgcWriteDataPatchSetAddressOrOffset | Graphics5 | 1 |
| `fRG-JOH5+sI` | sceAgcSetUcRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetUcRegIndirectPatchSetNumRegisters | Graphics5 | 1 |
| `fd5Bp5tGTgo` |  | `implemented` | Gen5::AgcFuseShaderHalves_0200 | Graphics5 | 1 |
| `h9z6+0hEydk` | sceAgcSuspendPoint | `implemented` | Gen5::AgcSuspendPoint | Graphics5 | 1 |
| `hEK26Wdny6s` | sceAgcDcbSetWorkloadComplete | `implemented` | Gen5::AgcDcbSetWorkloadComplete | Graphics5 | 1 |
| `hL7C0IRpWZI` | sceAgcCbQueueEndOfPipeActionGetSize | `implemented` | Gen5::AgcCbQueueEndOfPipeActionGetSize | Graphics5 | 1 |
| `htn36gPnBk4` | sceAgcAcbWaitRegMem | `implemented` | Gen5::AgcAcbWaitRegMem | Graphics5 | 1 |
| `hvUfkUIQcOE` | sceAgcDcbSetUcRegistersIndirect | `implemented` | Gen5::AgcDcbSetUcRegistersIndirect | Graphics5 | 1 |
| `idlaArvdXEs` | sceAgcAcbWaitOnAddressGetSize | `implemented` | Gen5::AgcAcbWaitOnAddressGetSize | Graphics5 | 1 |
| `k-JpyR2dYAM` |  | `implemented` | Gen5::AgcCondExecPatchSetEnd | Graphics5 | 1 |
| `kUlvghKs-mA` | sceAgcDcbDrawIndirectMulti | `implemented` | Gen5::AgcDcbDrawIndirectMulti | Graphics5 | 1 |
| `l4fM9K-Lyks` | sceAgcDcbSetIndexBuffer | `implemented` | Gen5::AgcDcbSetIndexBuffer | Graphics5 | 1 |
| `mR9j7+SfM34` | sceAgcDcbDrawIndexMultiInstancedGetSize | `implemented` | Gen5::AgcDcbDrawIndexMultiInstancedGetSize | Graphics5 | 1 |
| `n2fD4A+pb+g` | sceAgcCbSetShRegisterRangeDirect | `implemented` | Gen5::AgcCbSetShRegisterRangeDirect | Graphics5 | 1 |
| `n8vgpaQg6dA` | sceAgcSetRangePredication | `implemented` | Gen5::AgcSetRangePredication | Graphics5 | 1 |
| `nCUgItdN2ms` | sceAgcSetShRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetShRegIndirectPatchSetNumRegisters | Graphics5 | 1 |
| `nNlUtdDDvZ0` | sceAgcDcbSetShRegistersIndirectGetSize | `implemented` | Gen5::AgcDcbSetShRegistersIndirectGetSize | Graphics5 | 1 |
| `ou16V5hh5sg` | sceAgcDcbCondExecGetSize | `implemented` | Gen5::AgcDcbCondExecGetSize | Graphics5 | 1 |
| `ozKzBP4aki4` | sceAgcAcbCondExecGetSize | `implemented` | Gen5::AgcAcbCondExecGetSize | Graphics5 | 1 |
| `p9tI+yTvx68` | sceAgcDcbWriteDataGetSize | `implemented` | Gen5::AgcDcbWriteDataGetSize | Graphics5 | 1 |
| `pFLArOT53+w` | sceAgcDcbSetShRegisterDirect | `implemented` | Gen5::AgcDcbSetShRegisterDirect | Graphics5 | 1 |
| `qMlfB1ZhMDc` | sceAgcDcbDrawIndexOffsetGetSize | `implemented` | Gen5::AgcDcbDrawIndexOffsetGetSize | Graphics5 | 1 |
| `qj7QZpgr9Uw` |  | `implemented` | Gen5::AgcDcbContextStateOp | Graphics5 | 1 |
| `qyM2bxYFPAk` | sceAgcAcbCondExec | `implemented` | Gen5::AgcAcbCondExec | Graphics5 | 1 |
| `qzMN2XKGA4k` | sceAgcAcbCopyData | `implemented` | Gen5::AgcAcbCopyData | Graphics5 | 1 |
| `s+VGAMDQ0AQ` | sceAgcGetDataPacketPayloadRange | `implemented` | Gen5::AgcGetDataPacketPayloadRange | Graphics5 | 1 |
| `t7PlZ9nt5Lc` | sceAgcCbNopGetSize | `implemented` | Gen5::AgcCbNopGetSize | Graphics5 | 1 |
| `tSBxhAPyytQ` | sceAgcDcbSetNumInstances | `implemented` | Gen5::AgcDcbSetNumInstances | Graphics5 | 1 |
| `u2T2DiA5hRI` | sceAgcDcbStallCommandBufferParser | `implemented` | Gen5::AgcDcbStallCommandBufferParser | Graphics5 | 1 |
| `vRoArM9zaIk` | sceAgcSetUcRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetUcRegIndirectPatchAddRegisters | Graphics5 | 1 |
| `vcmNN+AAXnY` | sceAgcSetCxRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetCxRegIndirectPatchSetAddress | Graphics5 | 1 |
| `w4-d0n60hdo` | sceAgcDcbSetUcRegisterDirect | `implemented` | Gen5::AgcDcbSetUcRegisterDirect | Graphics5 | 1 |
| `w6Dj1VJt5qY` | sceAgcSetPacketPredication | `implemented` | Gen5::AgcSetPacketPredication | Graphics5 | 1 |
| `w8HVkEeXPv8` | sceAgcDcbDispatchIndirectGetSize | `implemented` | Gen5::AgcDcbDispatchIndirectGetSize | Graphics5 | 1 |
| `wRbq6ZjNop4` |  | `implemented` | Gen5::AgcGetRegisterDefaults2Internal | Graphics5 | 1 |
| `whb1RL7K4Ss` | sceAgcSetCxRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetCxRegIndirectPatchSetNumRegisters | Graphics5 | 1 |
| `xAeBOa0A3kk` | sceAgcAcbSetMarker | `implemented` | Gen5::AgcAcbSetMarker | Graphics5 | 1 |
| `xSAR0LTcRKM` | sceAgcDcbJump | `implemented` | Gen5::AgcDcbJump | Graphics5 | 1 |
| `ypVBz4uPKcQ` | sceAgcDcbDrawIndexIndirectMulti | `implemented` | Gen5::AgcDcbDrawIndexIndirectMulti | Graphics5 | 1 |
| `z2duB-hHQSM` | sceAgcSetShRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetShRegIndirectPatchAddRegisters | Graphics5 | 1 |
| `zfcxg-ewMK8` | sceAgcDcbRewind | `implemented` | Gen5::AgcDcbRewind | Graphics5 | 1 |
| `ziVA3whp3p4` | sceAgcRewindPatchSetRewindState | `implemented` | Gen5::AgcRewindPatchSetRewindState | Graphics5 | 1 |
| `1q1titRBL6o` | sceAgcDcbDrawIndirect | `implemented` | Gen5::AgcDcbDrawIndirect | Graphics5 | 0 |
| `B+aG9DUnTKA` | sceAgcDcbDrawIndexOffset | `implemented` | Gen5::AgcDcbDrawIndexOffset | Graphics5 | 0 |
| `CtB+A9-VxO0` | sceAgcDcbDispatchIndirect | `implemented` | Gen5::AgcDcbDispatchIndirect | Graphics5 | 0 |
| `D9sr1xGUriE` | sceAgcCreatePrimState | `implemented` | Gen5::AgcCreatePrimState | Graphics5 | 0 |
| `NKIzURsgV7I` | sceAgcGetGsOversubscription | `implemented` | Gen5::AgcGetGsOversubscription | Graphics5 | 0 |
| `Rlx+bykm0r0` | sceAgcDcbDrawIndexMultiInstanced | `implemented` | Gen5::AgcDcbDrawIndexMultiInstanced | Graphics5 | 0 |
| `Yw0jKSqop+E` | sceAgcDcbDrawIndexAuto | `implemented` | Gen5::AgcDcbDrawIndexAuto | Graphics5 | 0 |
| `dbOlWdppb4o` |  | `implemented` | Gen5::AgcCreateInterpolantMapping2 | Graphics5 | 0 |
| `dolOmWH+huQ` |  | `implemented` | Gen5::AgcGetFusedShaderSize | Graphics5 | 0 |
| `f3dg2CSgRKY` | sceAgcCreateShader | `implemented` | Gen5::AgcCreateShader | Graphics5 | 0 |
| `j3EtxFkSIhQ` | sceAgcAcbDispatchIndirect | `implemented` | Gen5::AgcAcbDispatchIndirect | Graphics5 | 0 |
| `k3GhuSNmBLU` | sceAgcCbDispatch | `implemented` | Gen5::AgcCbDispatch | Graphics5 | 0 |
| `q88lQ+GP5Yk` | sceAgcDcbDrawIndex | `implemented` | Gen5::AgcDcbDrawIndex | Graphics5 | 0 |
| `t1vNu082-jM` | sceAgcDcbDrawIndexIndirect | `implemented` | Gen5::AgcDcbDrawIndexIndirect | Graphics5 | 0 |
| `T6xuVw0KUJo` | sceAgcDebugRaiseException | `stub` | Gen5::AgcDebugRaiseException (return_constant) | Graphics5 | 1 |
| `G0jrLdvEqDw` |  | `missing` |  |  | 2 |
| `GXBlM-ekzrI` |  | `missing` |  |  | 2 |
| `hFQ9pUxoLQ4` |  | `missing` |  |  | 2 |
| `jt3pl7EN17o` |  | `missing` |  |  | 2 |
| `q4VuU-QsLOE` |  | `missing` |  |  | 2 |
| `rP5xLdOf26k` |  | `missing` |  |  | 2 |
| `rVOmPz2RBlg` |  | `missing` |  |  | 2 |
| `szG7hz2yEhA` |  | `missing` |  |  | 2 |
| `+u6dKSLWM2o` |  | `missing` |  |  | 1 |
| `0ZOG0jc9nRg` |  | `missing` |  |  | 1 |
| `0o3VDdtA6nM` |  | `missing` |  |  | 1 |
| `1-gUn1PI4Sw` |  | `missing` |  |  | 1 |
| `1tB0xkLNjcw` |  | `missing` |  |  | 1 |
| `2ccJz9LQI+w` |  | `missing` |  |  | 1 |
| `6nths4DHNrs` |  | `missing` |  |  | 1 |
| `7toV+elXqNM` |  | `missing` |  |  | 1 |
| `8Kly1JrJUlw` |  | `missing` |  |  | 1 |
| `9S4noWrUI0s` |  | `missing` |  |  | 1 |
| `AAeX-U5-P3M` |  | `missing` |  |  | 1 |
| `AFIh8SQkYlQ` |  | `missing` |  |  | 1 |
| `BYcSvEsINWU` |  | `missing` |  |  | 1 |
| `EJBA4dbmvfg` |  | `missing` |  |  | 1 |
| `F8NLhWvFemI` |  | `missing` |  |  | 1 |
| `FcgdDM3MB+k` |  | `missing` |  |  | 1 |
| `FneFypEDRgY` |  | `missing` |  |  | 1 |
| `FuVbkyKlf+s` |  | `missing` |  |  | 1 |
| `GPbUp9jXQa8` |  | `missing` |  |  | 1 |
| `J8YCgfKAMQs` |  | `missing` |  |  | 1 |
| `JOWmDrl+j20` |  | `missing` |  |  | 1 |
| `KjPeVduz6jU` |  | `missing` |  |  | 1 |
| `M0ttm8h7SKA` |  | `missing` |  |  | 1 |
| `MDLD5Ly94Xk` |  | `missing` |  |  | 1 |
| `MMlmJAL7N5w` |  | `missing` |  |  | 1 |
| `N7M3+N-sBCw` |  | `missing` |  |  | 1 |
| `OQTgEXyihvA` |  | `missing` |  |  | 1 |
| `P1CugZ99Uzc` |  | `missing` |  |  | 1 |
| `PxKWV2fVAps` |  | `missing` |  |  | 1 |
| `QhPDD513V0w` |  | `missing` |  |  | 1 |
| `RTpj-tIlvZc` |  | `missing` |  |  | 1 |
| `SwI6QxqwAC0` |  | `missing` |  |  | 1 |
| `T9fjQIINoeE` |  | `missing` |  |  | 1 |
| `TGEZzUWLbrc` |  | `missing` |  |  | 1 |
| `UQGTw4xRlcM` |  | `missing` |  |  | 1 |
| `W0WEyog0f74` |  | `missing` |  |  | 1 |
| `XKKuA6VkSRc` |  | `missing` |  |  | 1 |
| `XN+Iuu7XsM8` |  | `missing` |  |  | 1 |
| `Y-5vneiBtzk` |  | `missing` |  |  | 1 |
| `aP1Ki9G3++4` |  | `missing` |  |  | 1 |
| `ca4KPvp0qLQ` |  | `missing` |  |  | 1 |
| `d4NZIlguzv0` |  | `missing` |  |  | 1 |
| `da1Sm8-QDoU` |  | `missing` |  |  | 1 |
| `eAy8eGNsCuU` |  | `missing` |  |  | 1 |
| `eCjKaqeeQ5s` |  | `missing` |  |  | 1 |
| `ebixW91gpPw` |  | `missing` |  |  | 1 |
| `gQkqkLttcpw` |  | `missing` |  |  | 1 |
| `hcIxS8pmXF4` |  | `missing` |  |  | 1 |
| `j4emHHndCPY` |  | `missing` |  |  | 1 |
| `mStuvI0zOtc` |  | `missing` |  |  | 1 |
| `mljzuGDZRQ4` |  | `missing` |  |  | 1 |
| `ms1xVoZ-Vwc` |  | `missing` |  |  | 1 |
| `n485EBnIWmk` |  | `missing` |  |  | 1 |
| `opR1JeJZCBU` |  | `missing` |  |  | 1 |
| `oz6zQq1JwCE` |  | `missing` |  |  | 1 |
| `pYoKs3lPy88` |  | `missing` |  |  | 1 |
| `pxx-GoOSdw4` |  | `missing` |  |  | 1 |
| `r98I08t+LOg` |  | `missing` |  |  | 1 |
| `rUuVjyR+Rd4` |  | `missing` |  |  | 1 |
| `tmy-+rBpspY` |  | `missing` |  |  | 1 |
| `v3G+IipShZs` |  | `missing` |  |  | 1 |
| `vLrBL8DQiz8` |  | `missing` |  |  | 1 |
| `y5K5tPktiL8` |  | `missing` |  |  | 1 |
| `yUBESvCCJ4I` |  | `missing` |  |  | 1 |
| `yheJGN-ay+A` |  | `missing` |  |  | 1 |
| `zARR5aCmkoY` |  | `missing` |  |  | 1 |
| `zg6u-N6Otxs` |  | `missing` |  |  | 1 |
| `ICkECTBxrMw` |  | `missing` |  |  | 0 |
| `vieBRwlh1Lw` |  | `missing` |  |  | 0 |

## libSceAgcDriver

| NID | Nome verificado | Status | Função no engine | Biblioteca na HLE | Sítios |
|---|---|---|---|---|---:|
| `DL2RXaXOy88` | sceAgcDriverDeleteEqEvent | `implemented` | Gen5Driver::AgcDriverDeleteEqEvent | Graphics5Driver | 2 |
| `w2rJhmD+dsE` | sceAgcDriverAddEqEvent | `implemented` | Gen5Driver::AgcDriverAddEqEvent | Graphics5Driver | 2 |
| `+T8Xo6LtFJI` |  | `implemented` | Gen5Driver::AgcDriverSubmitMultiDcbs | Graphics5Driver | 1 |
| `3AyTaWcF-H8` | sceAgcDriverRegisterWorkloadStream | `implemented` | Gen5::AgcDriverRegisterWorkloadStream | Graphics5 | 1 |
| `5CdQTZIQPxM` | sceAgcDriverGetEqEventType | `implemented` | Gen5Driver::AgcDriverGetEqEventType | Graphics5Driver | 1 |
| `6UzEidRZwkg` | sceAgcDriverSubmitMultiDcbs | `implemented` | Gen5Driver::AgcDriverSubmitMultiDcbs | Graphics5Driver | 1 |
| `AOLcoIkQDgM` | sceAgcDriverQueryResourceRegistrationUserMemoryRequirements | `implemented` | Gen5::AgcDriverQueryResourceRegistrationUserMemoryRequirements | Graphics5 | 1 |
| `AhGvpITrf4M` |  | `implemented` | Gen5Driver::AgcDriverSubmitDcb | Graphics5Driver | 1 |
| `F0Y42t-3e18` | sceAgcDriverInitResourceRegistration | `implemented` | Gen5::AgcDriverInitResourceRegistration | Graphics5 | 1 |
| `F0ZXt5q0ZTA` | sceAgcDriverGetDefaultOwner | `implemented` | Gen5::AgcDriverGetDefaultOwner | Graphics5 | 1 |
| `HF3YllT3mXU` | sceAgcDriverSubmitMultiAcbs | `implemented` | Gen5Driver::AgcDriverSubmitMultiAcbs | Graphics5Driver | 1 |
| `U9ueyEhSkF4` | sceAgcDriverRegisterDefaultOwner | `implemented` | Gen5Driver::AgcDriverRegisterDefaultOwner | Graphics5Driver | 1 |
| `UglJIZjGssM` | sceAgcDriverSubmitDcb | `implemented` | Gen5Driver::AgcDriverSubmitDcb | Graphics5Driver | 1 |
| `W5z4eZrjEas` | sceAgcDriverRegisterResource | `implemented` | Gen5::AgcDriverRegisterResource | Graphics5 | 1 |
| `X-Nm5KLREeg` | sceAgcDriverRegisterOwner | `implemented` | Gen5::AgcDriverRegisterOwner | Graphics5 | 1 |
| `ZLJk9r2+2Aw` | sceAgcDriverUnregisterOwnerAndResources | `implemented` | Gen5::AgcDriverUnregisterOwnerAndResources | Graphics5 | 1 |
| `Zw7uUVPulbw` | sceAgcDriverGetEqContextId | `implemented` | Gen5Driver::AgcDriverGetEqContextId | Graphics5Driver | 1 |
| `gSRnr79F8tQ` | sceAgcDriverSubmitAcb | `implemented` | Gen5Driver::AgcDriverSubmitAcb | Graphics5Driver | 1 |
| `pWLG7WOpVcw` | sceAgcDriverUnregisterResource | `implemented` | Gen5::AgcDriverUnregisterResource | Graphics5 | 1 |
| `uJziRsODk1c` | sceAgcDriverGetResourceRegistrationMaxNameLength | `implemented` | Gen5::AgcDriverGetResourceRegistrationMaxNameLength | Graphics5 | 1 |
| `Ddwk4gLT5j0` | sceAgcDriverIsCaptureInProgress | `stub` | Gen5Driver::AgcDriverIsCaptureInProgress (return_constant) | Graphics5Driver | 1 |
| `Xq5WmbwPTnQ` |  | `missing` |  |  | 2 |
| `+TN0oRTBxJQ` |  | `missing` |  |  | 1 |
| `+iAOE3jCnkk` |  | `missing` |  |  | 1 |
| `5l3IfCFJxBs` |  | `missing` |  |  | 1 |
| `8F5j7U-Bq6s` |  | `missing` |  |  | 1 |
| `FOwvmNlFLjM` |  | `missing` |  |  | 1 |
| `ICaGtkEIXTk` |  | `missing` |  |  | 1 |
| `JQc0956gCf0` |  | `missing` |  |  | 1 |
| `LepGrgk77sM` |  | `missing` |  |  | 1 |
| `M9yBzRKkjPc` |  | `missing` |  |  | 1 |
| `NghWEUXp1qM` |  | `missing` |  |  | 1 |
| `SAfhzJPcjuk` |  | `missing` |  |  | 1 |
| `SCoAN5fYlUM` |  | `missing` |  |  | 1 |
| `VOMSpd9+vxU` |  | `missing` |  |  | 1 |
| `WHIOMbb+iIU` |  | `missing` |  |  | 1 |
| `chJWZcNSzjk` |  | `missing` |  |  | 1 |
| `emP3ckeS2uo` |  | `missing` |  |  | 1 |
| `ls4jfY576lw` |  | `missing` |  |  | 1 |
| `mXn+K9E-wOA` |  | `missing` |  |  | 1 |
| `n5ElQVYsU1A` |  | `missing` |  |  | 1 |
| `qspAL8bgcBY` |  | `missing` |  |  | 1 |
| `rI9lNAXPMIw` |  | `missing` |  |  | 1 |
| `rJUyMrDdxJg` |  | `missing` |  |  | 1 |

## libSceVideoOut

| NID | Nome verificado | Status | Função no engine | Biblioteca na HLE | Sítios |
|---|---|---|---|---|---:|
| `CBiu4mCE1DA` | sceVideoOutSetFlipRate | `implemented` | VideoOut::VideoOutSetFlipRate | VideoOut | 5 |
| `utPrVdxio-8` | sceVideoOutGetOutputStatus | `implemented` | VideoOut::VideoOutGetOutputStatus | VideoOut | 3 |
| `zgXifHT9ErY` | sceVideoOutIsFlipPending | `implemented` | VideoOut::VideoOutIsFlipPending | VideoOut | 3 |
| `DYhhWbJSeRg` |  | `implemented` | VideoOut::VideoOutColorSettingsSetGamma | VideoOut | 2 |
| `HuViW4HnrOw` | sceVideoOutSubmitChangeBufferAttribute2 | `implemented` | VideoOut::VideoOutSubmitChangeBufferAttribute2 | VideoOut | 2 |
| `N5KDtkIjjJ4` | sceVideoOutUnregisterBuffers | `implemented` | VideoOut::VideoOutUnregisterBuffers | VideoOut | 2 |
| `PjS5uASwcV8` | sceVideoOutSetBufferAttribute2 | `implemented` | VideoOut::VideoOutSetBufferAttribute2 | VideoOut | 2 |
| `U46NwOiJpys` | sceVideoOutSubmitFlip | `implemented` | VideoOut::VideoOutSubmitFlip | VideoOut | 2 |
| `j6RaAUlaLv0` | sceVideoOutWaitVblank | `implemented` | VideoOut::VideoOutWaitVblank | VideoOut | 2 |
| `pv9CI5VC+R0` |  | `implemented` | VideoOut::VideoOutAdjustColor | VideoOut | 2 |
| `MTxxrOCeSig` | sceVideoOutSetWindowModeMargins | `implemented` | VideoOut::VideoOutSetWindowModeMargins | VideoOut | 1 |
| `Up36PTk687E` | sceVideoOutOpen | `implemented` | VideoOut::VideoOutOpen | VideoOut | 1 |
| `rKBUtgRrtbk` | sceVideoOutRegisterBuffers2 | `implemented` | VideoOut::VideoOutRegisterBuffers2 | VideoOut | 1 |
| `uquVH4-Du78` | sceVideoOutClose | `implemented` | VideoOut::VideoOutClose | VideoOut | 1 |

## libSceAmpr

| NID | Nome verificado | Status | Função no engine | Biblioteca na HLE | Sítios |
|---|---|---|---|---|---:|
| `I-Qm+MEso5c` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 6 |
| `jK+yuYCI7MA` |  | `implemented` | Ampr::CommandBufferWriteCounter | Ampr | 6 |
| `ClnsFLLLcss` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 4 |
| `cQb8Zr8Q0Y0` |  | `implemented` | Ampr::CommandBufferWaitOnCounter | Ampr | 4 |
| `2Hw8gjMdwSY` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 2 |
| `4fgtGfXDrFc` |  | `implemented` | Ampr::MeasureCommandSizeWriteAddress | Ampr | 2 |
| `8aI7R7WaOlc` |  | `implemented` | Ampr::CommandBufferConstructor | Ampr | 2 |
| `GuchCTefuZw` |  | `implemented` | Ampr::CommandBufferDestructor | Ampr | 2 |
| `H896Pt-yB4I` |  | `implemented` | Ampr::CommandBufferWriteKernelEventQueue | Ampr | 2 |
| `JYd9g9L+TmE` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 2 |
| `bt3LHR9xjK4` |  | `implemented` | Ampr::CommandBufferWriteAddressFromTimeCounter | Ampr | 2 |
| `enZm-6GjWqw` |  | `implemented` | Ampr::CommandBufferWriteAddressFromCounterPair | Ampr | 2 |
| `gAtc79UTt5E` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 2 |
| `j0+3uJMxYJY` |  | `implemented` | Ampr::CommandBufferWriteAddress | Ampr | 2 |
| `sSAUCCU1dv4` |  | `implemented` | Ampr::MeasureCommandSizeWriteKernelEventQueue | Ampr | 2 |
| `t4ExS+SwLjs` |  | `implemented` | Ampr::CommandBufferWriteAddressFromCounter | Ampr | 2 |
| `0BMj1hgG+kE` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | Ampr | 1 |
| `0RdLmAh7WVo` |  | `implemented` | Ampr::MeasureCommandSizeMarker | Ampr | 1 |
| `3OfeY4pzDV0` |  | `implemented` | Ampr::MeasureCommandSizeMarkerWithColor | Ampr | 1 |
| `4UkZbYKVF7c` |  | `implemented` | Ampr::CommandBufferConstructMarker | Ampr | 1 |
| `4quckD2y7Pg` |  | `implemented` | Ampr::CommandBufferSetMarker | Ampr | 1 |
| `7nXGDGMXSqo` |  | `implemented` | Ampr::MeasureCommandSizeReadFileScatter | Ampr | 1 |
| `BVmR1H8l+XI` |  | `implemented` | Ampr::AprCommandBufferReadFileGatherScatter | Ampr | 1 |
| `DLfoNxTFNVk` |  | `implemented` | Ampr::CommandBufferWaitOnAddress | Ampr | 1 |
| `DXmgc5op8Yw` |  | `implemented` | Ampr::MeasureCommandSizeReadFileGatherScatter | Ampr | 1 |
| `Eul7AGEpjLo` |  | `implemented` | Ampr::AprCommandBufferMapBegin | Ampr | 1 |
| `GmOguNIsuKk` |  | `implemented` | Ampr::CommandBufferConstructNop | Ampr | 1 |
| `GnxKOHEawhk` |  | `implemented` | Ampr::CommandBufferGetCurrentOffset | Ampr | 1 |
| `Jg-AgkdJHkk` |  | `implemented` | Ampr::AprCommandBufferReadFileScatter | Ampr | 1 |
| `N-FSPA4S3nI` |  | `implemented` | Ampr::CommandBufferSetBuffer | Ampr | 1 |
| `NNIZ-FMyz3M` |  | `implemented` | Ampr::MeasureCommandSizeNop | Ampr | 1 |
| `RPCAhx-aabE` |  | `implemented` | Ampr::CommandBufferGetBufferBaseAddress | Ampr | 1 |
| `ULvXMDz56po` |  | `implemented` | Ampr::CommandBufferClearBuffer | Ampr | 1 |
| `VEDMaQmJZng` |  | `implemented` | Ampr::CommandBufferGetType | Ampr | 1 |
| `VGkEj4d6-Kg` |  | `implemented` | Ampr::MeasureCommandSizeMarker | Ampr | 1 |
| `X169CE6G3Y4` |  | `implemented` | Ampr::AprCommandBufferMapEnd | Ampr | 1 |
| `Xp85BP3+BBI` |  | `implemented` | Ampr::MeasureCommandSizeNopWithData | Ampr | 1 |
| `YPxkUDhgoNI` |  | `implemented` | Ampr::AprCommandBufferResetGatherScatterState | Ampr | 1 |
| `a8uLzYY--tM` |  | `implemented` | Ampr::AprCommandBufferConstructor | Ampr | 1 |
| `bFEs0Gs6D2A` |  | `implemented` | Ampr::AprCommandBufferMapDirectBegin | Ampr | 1 |
| `baQO9ez2gL4` |  | `implemented` | Ampr::CommandBufferReset | Ampr | 1 |
| `dXPaz65HNmk` |  | `implemented` | Ampr::CommandBufferPushMarker | Ampr | 1 |
| `f12ObAMEi9A` |  | `implemented` | Ampr::CommandBufferPushMarkerWithColor | Ampr | 1 |
| `gzndltBEzWc` |  | `implemented` | Ampr::CommandBufferGetNumCommands | Ampr | 1 |
| `iwTNhyaemnw` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | Ampr | 1 |
| `kdFImtTD0hc` |  | `implemented` | Ampr::MeasureAprCommandSizeMapBegin | Ampr | 1 |
| `mQ16-QdKv7k` |  | `implemented` | Ampr::AprCommandBufferReadFile | Ampr | 1 |
| `mZSbNJVJpV8` |  | `implemented` | Ampr::AprCommandBufferReadFileGather | Ampr | 1 |
| `mv0O8Zg0woU` |  | `implemented` | Ampr::CommandBufferPopMarker | Ampr | 1 |
| `pFQ9UHpO52s` |  | `implemented` | Ampr::CommandBufferNopWithData | Ampr | 1 |
| `pbnNnahE8vk` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | Ampr | 1 |
| `qesF88X4DRg` |  | `implemented` | Ampr::MeasureCommandSizeReadFileGather | Ampr | 1 |
| `qvbdJc7bG+s` |  | `implemented` | Ampr::MeasureAprCommandSizeMapDirectBegin | Ampr | 1 |
| `rddQYXM0CjM` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | Ampr | 1 |
| `sWbST0oQKsc` |  | `implemented` | Ampr::CommandBufferSetMarkerWithColor | Ampr | 1 |
| `tNn5WBkta60` |  | `implemented` | Ampr::CommandBufferNop | Ampr | 1 |
| `tZDDEo2tE5k` |  | `implemented` | Ampr::CommandBufferGetSize | Ampr | 1 |
| `tmfr97+ED5I` |  | `implemented` | Ampr::MeasureCommandSizeMarkerWithColor | Ampr | 1 |
| `vWU-odnS+fU` |  | `implemented` | Ampr::MeasureCommandSizeReadFile | Ampr | 1 |
| `Qs1xtplKo0U` |  | `stub` | Ampr::AprCommandBufferDestructor (return_constant) | Ampr | 1 |

