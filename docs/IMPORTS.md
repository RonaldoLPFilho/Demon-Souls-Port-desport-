# Cobertura dos imports do jogo

> Gerado por `tools/nid_db.py` a partir de `out/inventory.json` e do código de `engine/src`. Não editar à mão.

Jogo: `PPSA01341` região EU versão 01.007.000. Engine: 1788 registros HLE, 1736 definições `KYTY_SYSV_ABI` lidas.

## Resumo (eboot.bin)

| Status | Imports | % |
|---|---:|---:|
| `implemented` | 665 | 56.3% |
| `stub` | 31 | 2.6% |
| `missing` | 129 | 10.9% |
| `provided_by_game_module` | 356 | 30.1% |
| **total** | **1181** | |

**Funções que faltam (`missing` + `stub`): 160.** Resolvidos só pelo NID (sem casar biblioteca/módulo): 165.

Imports dos módulos do dump (`sce_module/`): implemented 184, stub 9, missing 12, provided_by_game_module 9.

### 20 bibliotecas com mais `missing` + `stub`

| Biblioteca | missing | stub | implemented | módulo do jogo | total |
|---|---:|---:|---:|---:|---:|
| libSceAgc | 77 | 1 | 133 | 0 | 211 |
| libSceAgcDriver | 23 | 1 | 20 | 0 | 44 |
| libSceNpWebApi2 | 6 | 4 | 10 | 0 | 20 |
| libSceNpSessionSignaling | 6 | 1 | 0 | 0 | 7 |
| libSceAjm | 1 | 4 | 14 | 0 | 19 |
| libSceJpegEnc | 4 | 0 | 0 | 0 | 4 |
| libSceJson2 | 0 | 3 | 2 | 0 | 5 |
| libSceNet | 3 | 0 | 31 | 0 | 34 |
| libSceAcm | 0 | 2 | 3 | 0 | 5 |
| libSceCommonDialog | 0 | 2 | 0 | 0 | 2 |
| libSceNpManager | 1 | 1 | 14 | 0 | 16 |
| libScePsml | 2 | 0 | 11 | 0 | 13 |
| libSceSaveData_native | 0 | 2 | 11 | 0 | 13 |
| libSceSsl | 2 | 0 | 2 | 0 | 4 |
| libSceSystemGesture | 0 | 2 | 7 | 0 | 9 |
| libSceAmpr | 0 | 1 | 59 | 0 | 60 |
| libSceAudioOut2 | 0 | 1 | 14 | 0 | 15 |
| libSceCoredump | 1 | 0 | 2 | 0 | 3 |
| libSceHttp | 1 | 0 | 22 | 0 | 23 |
| libSceHttp2 | 1 | 0 | 13 | 0 | 14 |

### Critérios

- A ordem de resolução segue `RuntimeLinker::Resolve`: HLE com chave exata, export de módulo com a mesma biblioteca/módulo, depois só pelo NID e tipo.
- `stub` (heurística sobre o corpo da função, sem comentários/strings):
  - `name`: nome da função contém "Stub" ou "Unknown"
  - `empty`: corpo sem nenhuma instrução além de log/validação
  - `return_constant`: corpo só loga/valida e retorna uma constante neutra (OK, 0, -1, nullptr, true/false) ou um código de erro; algumas estão corretas assim (ex.: "captura em andamento" = false), por isso é "stub provável"
  - `aborts`: corpo só aborta (EXIT/EXIT_NOT_IMPLEMENTED)
- `body_not_found`: a função registrada não foi achada como definição `KYTY_SYSV_ABI`; conta como `implemented` e merece conferência manual.
- Sítios de chamada: varredura de bytes (`call/jmp rel32` para stubs PLT e `call [rip+GOT]`); serve para ordenar por uso, pode ter falsos positivos.
- Nomes: só os verificados pelo hash do NID.

## Por biblioteca (eboot.bin)

### libSceAcm

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `8fe55ktlNVo` | sceAcmBatchStartBuffers | `implemented` | Acm::AcmBatchStartBuffers | 2 | 0x1de4993, 0x1dfcfca |
| `ZIXln2K3XMk` | sceAcmContextCreate | `implemented` | Acm::AcmContextCreate | 1 | 0x1de468f |
| `u70oWo92SYQ` |  | `implemented` | Acm::AcmConvReverbSharedInput | 1 | 0x1dfcfa1 |
| `RLN3gRlXJLE` | sceAcmBatchWait | `stub` | Acm::AcmBatchWait (return_constant) | 4 | 0x1de4778, 0x1de4855, 0x1dfafe2 |
| `jBgBjAj02R8` | sceAcmContextDestroy | `stub` | Acm::AcmContextDestroy (return_constant) | 1 | 0x1de47ff |

### libSceAgc

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `RmaJwLtc8rY` | sceAgcDcbSetBaseIndirectArgs | `implemented` | Gen5::AgcDcbSetBaseIndirectArgs [só NID] | 3 | 0x1d0b1b8, 0x1d0b1c5, 0x1d0b1d5 |
| `aJf+j5yntiU` | sceAgcDcbEventWrite | `implemented` | Gen5::AgcDcbEventWrite [só NID] | 3 | 0x1d0b130, 0x1d0b323, 0x1d0b359 |
| `bbFueFP+J4k` | sceAgcDcbSetPredication | `implemented` | Gen5::AgcDcbSetPredication [só NID] | 3 | 0x1d0b36a, 0x1d0b37d, 0x1d0b39f |
| `wr23dPKyWc0` | sceAgcCbReleaseMem | `implemented` | Gen5::AgcCbReleaseMem [só NID] | 3 | 0x1d0a980, 0x1d0ac34, 0x1d0afcc |
| `7Wa3aeJgeVU` |  | `implemented` | Gen5::AgcBranchPatchSetThenTarget [só NID] | 2 | 0x1d0fac0, 0x1d0faf7 |
| `7nOoijNPvEU` | sceAgcWaitRegMemPatchReference | `implemented` | Gen5::AgcWaitRegMemPatchReference [só NID] | 2 | 0x1d0fce0, 0x1d0fcf0 |
| `Ikfdt-rIqCE` |  | `implemented` | Gen5::AgcJumpPatchSetTarget_0300 [só NID] | 2 | 0x1d0fb20, 0x1d0fb37 |
| `LFSPFmGc9Hg` | sceAgcDcbSetWorkloadsActive | `implemented` | Gen5::AgcDcbSetWorkloadsActive [só NID] | 2 | 0x1d0b503, 0x1d0b520 |
| `V++UgBtQhn0` |  | `implemented` | Gen5::AgcGetDataPacketPayloadAddress [só NID] | 2 | 0x1d0fc72, 0x1d0fc95 |
| `i1jyy49AjXU` | sceAgcDcbWriteData | `implemented` | Gen5::AgcDcbWriteData [só NID] | 2 | 0x1d0af90, 0x1d0b30f |
| `uZW-mqsxkrM` | sceAgcCbBranchGetSize | `implemented` | Gen5::AgcCbBranchGetSize [só NID] | 2 | 0x1d0aab0, 0x1d0aac0 |
| `vuSXe69VILM` | sceAgcDcbGetLodStats | `implemented` | Gen5::AgcDcbGetLodStats [só NID] | 2 | 0x1d0b161, 0x1d0b18b |
| `w1KFAHVqpaU` | sceAgcCbBranch | `implemented` | Gen5::AgcCbBranch [só NID] | 2 | 0x1d0a8e8, 0x1d0af30 |
| `+kSrjIVxKFE` | sceAgcDcbPushMarker | `implemented` | Gen5::AgcDcbPushMarker [só NID] | 1 | 0x1d0b3f0 |
| `-HOOCn0JY48` | sceAgcDcbSetShRegistersIndirect | `implemented` | Gen5::AgcDcbSetShRegistersIndirect [só NID] | 1 | 0x1d0afe0 |
| `-KRzWekV120` |  | `implemented` | Gen5::AgcDcbSetIndexSize_0600 [só NID] | 1 | 0x1d0b1e0 |
| `-RnpfpxIhec` | sceAgcAcbDmaData | `implemented` | Gen5::AgcAcbDmaData [só NID] | 1 | 0x1d0ab90 |
| `-vnlTPPXPrw` | sceAgcDcbAcquireMemGetSize | `implemented` | Gen5::AgcDcbAcquireMemGetSize [só NID] | 1 | 0x1d0b5b0 |
| `03RZmELWWzw` | sceAgcCbSetUcRegistersDirect | `implemented` | Gen5::AgcCbSetUcRegistersDirect [só NID] | 1 | 0x1d0a9e0 |
| `0fWWK5uG9rQ` | sceAgcQueueEndOfPipeActionPatchAddress | `implemented` | Gen5::AgcQueueEndOfPipeActionPatchAddress [só NID] | 1 | 0x1d0fd00 |
| `1DeUNpRIDDA` | sceAgcDcbSetCxRegisterDirectGetSize | `implemented` | Gen5::AgcDcbSetCxRegisterDirectGetSize [só NID] | 1 | 0x1d0b590 |
| `1rZSWUv1IRc` | sceAgcDcbCopyData | `implemented` | Gen5::AgcDcbCopyData [só NID] | 1 | 0x1d0af70 |
| `23LRUSvYu1M` |  | `implemented` | Gen5::AgcInit [só NID] | 1 | 0x1d09609 |
| `2JtWUUiYBXs` | sceAgcGetRegisterDefaults2 | `implemented` | Gen5::AgcGetRegisterDefaults2 [só NID] | 1 | 0x1d064b4 |
| `3KDcnM3lrcU` | sceAgcWaitRegMemPatchAddress | `implemented` | Gen5::AgcWaitRegMemPatchAddress [só NID] | 1 | 0x1d0fcc0 |
| `3ZWa3AoyWZQ` |  | `implemented` | Gen5::AgcCondExecPatchSetCommandAddress [só NID] | 1 | 0x1d0fc00 |
| `43WJ08sSugE` | sceAgcDcbWaitOnAddressGetSize | `implemented` | Gen5::AgcDcbWaitOnAddressGetSize [só NID] | 1 | 0x1d0b770 |
| `57labkp+rSQ` | sceAgcDcbAcquireMem | `implemented` | Gen5::AgcDcbAcquireMem [só NID] | 1 | 0x1d0af10 |
| `6DFuRKT4C9w` | sceAgcDcbSetNumInstancesGetSize | `implemented` | Gen5::AgcDcbSetNumInstancesGetSize [só NID] | 1 | 0x1d0b750 |
| `6ee9Hd3EWXQ` | sceAgcDcbDrawIndexGetSize | `implemented` | Gen5::AgcDcbDrawIndexGetSize [só NID] | 1 | 0x1d0b670 |
| `6lNcCp+fxi4` | sceAgcSetUcRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetUcRegIndirectPatchSetAddress [só NID] | 1 | 0x1d0fba0 |
| `6mFxkVqdmbQ` | sceAgcAcbPopMarker | `implemented` | Gen5::AgcAcbPopMarker [só NID] | 1 | 0x1d0ad00 |
| `8N2tmT3jmC8` | sceAgcDcbSetIndexCount | `implemented` | Gen5::AgcDcbSetIndexCount [só NID] | 1 | 0x1d0b200 |
| `Abendgtz+3o` | sceAgcCbDispatchGetSize | `implemented` | Gen5::AgcCbDispatchGetSize [só NID] | 1 | 0x1d0aaa0 |
| `BIPexNBSGog` | sceAgcDcbCondExec | `implemented` | Gen5::AgcDcbCondExec [só NID] | 1 | 0x1d0af50 |
| `BfBDZGbti7A` | sceAgcGetIsTrinityMode | `implemented` | Gen5::AgcGetIsTrinityMode [só NID] | 1 | 0x1d0966e |
| `C4l9fB17t8w` | sceAgcDcbEventWriteGetSize | `implemented` | Gen5::AgcDcbEventWriteGetSize [só NID] | 1 | 0x1d0b6e0 |
| `CbQh3DKMSno` | sceAgcAcbCopyDataGetSize | `implemented` | Gen5::AgcAcbCopyDataGetSize [só NID] | 1 | 0x1d0ae90 |
| `DwICrVxerkY` | sceAgcAcbRewind | `implemented` | Gen5::AgcAcbRewind [só NID] | 1 | 0x1d0ac70 |
| `GBCh3zCihoU` | sceAgcDcbSetCxRegistersIndirectGetSize | `implemented` | Gen5::AgcDcbSetCxRegistersIndirectGetSize [só NID] | 1 | 0x1d0b560 |
| `H6vHS5cidSA` | sceAgcDcbContextStateOpGetSize | `implemented` | Gen5::AgcDcbContextStateOpGetSize [só NID] | 1 | 0x1d0b5f0 |
| `H7uZqCoNuWk` | sceAgcDcbPopMarker | `implemented` | Gen5::AgcDcbPopMarker [só NID] | 1 | 0x1d0b410 |
| `IxYiarKlXxM` | sceAgcDmaDataPatchSetDstAddressOrOffset | `implemented` | Gen5::AgcDmaDataPatchSetDstAddressOrOffset [só NID] | 1 | 0x1d0fca0 |
| `JrtiDtKeS38` | sceAgcAcbResetQueue | `implemented` | Gen5::AgcAcbResetQueue [só NID] | 1 | 0x1d0ac89 |
| `K2mciNVxUCE` | sceAgcSetNop | `implemented` | Gen5::AgcSetNop [só NID] | 1 | 0x1d0fc60 |
| `KT-hTp-Ch14` | sceAgcAcbAcquireMem | `implemented` | Gen5::AgcAcbAcquireMem [só NID] | 1 | 0x1d0ab50 |
| `LHFXRrlTPD8` | sceAgcDcbSetCxRegisterDirect | `implemented` | Gen5::AgcDcbSetCxRegisterDirect [só NID] | 1 | 0x1d0b020 |
| `Lkf86B98qPc` | sceAgcGetPacketSize | `implemented` | Gen5::AgcGetPacketSize [só NID] | 1 | 0x1d0fc50 |
| `LtTouSCZjHM` | sceAgcCbNop | `implemented` | Gen5::AgcCbNop [só NID] | 1 | 0x1d0a9a0 |
| `MWiElSNE8j8` | sceAgcDcbWaitUntilSafeForRendering | `implemented` | Gen5::AgcDcbWaitUntilSafeForRendering [só NID] | 1 | 0x1d0b3c0 |
| `MlEw1feXcjg` | sceAgcQueueEndOfPipeActionPatchData | `implemented` | Gen5::AgcQueueEndOfPipeActionPatchData [só NID] | 1 | 0x1d0fd20 |
| `ORWsxIbk4TE` | sceAgcCondExecPatchSetEnd | `implemented` | Gen5::AgcCondExecPatchSetEnd [só NID] | 1 | 0x1d0fbd0 |
| `QIXCsbipds0` | sceAgcDcbRewindGetSize | `implemented` | Gen5::AgcDcbRewindGetSize [só NID] | 1 | 0x1d0b780 |
| `QhCbS4X9Rl8` | sceAgcDcbSetMarker | `implemented` | Gen5::AgcDcbSetMarker [só NID] | 1 | 0x1d0b3d0 |
| `Qrj4c+61z4A` | sceAgcSetShRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetShRegIndirectPatchSetAddress [só NID] | 1 | 0x1d0fb40 |
| `TRO721eVt4g` | sceAgcDcbResetQueue | `implemented` | Gen5::AgcDcbResetQueue [só NID] | 1 | 0x1d0b279 |
| `UZbQjYAwwXM` | sceAgcCbSetShRegistersDirect | `implemented` | Gen5::AgcCbSetShRegistersDirect [só NID] | 1 | 0x1d0a9d0 |
| `VEGu4dixjUg` | sceAgcDcbJumpGetSize | `implemented` | Gen5::AgcDcbJumpGetSize [só NID] | 1 | 0x1d0b600 |
| `VmW0Tdpy420` | sceAgcDcbWaitRegMem | `implemented` | Gen5::AgcDcbWaitRegMem [só NID] | 1 | 0x1d0b230 |
| `WmAc2MEj6Io` | sceAgcDcbDmaData | `implemented` | Gen5::AgcDcbDmaData [só NID] | 1 | 0x1d0af80 |
| `WrdP9Zxx3lQ` | sceAgcDcbDrawIndexAutoGetSize | `implemented` | Gen5::AgcDcbDrawIndexAutoGetSize [só NID] | 1 | 0x1d0b660 |
| `Y3ymLfZ1384` | sceAgcUpdatePrimState | `implemented` | Gen5::AgcUpdatePrimState [só NID] | 1 | 0x1d0a6b0 |
| `YUeqkyT7mEQ` | sceAgcDcbSetFlip | `implemented` | Gen5::AgcDcbSetFlip [só NID] | 1 | 0x1d0b420 |
| `YWTKOju587o` | sceAgcCondExecPatchSetCommandAddress | `implemented` | Gen5::AgcCondExecPatchSetCommandAddress [só NID] | 1 | 0x1d0fbe0 |
| `ZvwO9euwYzc` | sceAgcDcbSetCxRegistersIndirect | `implemented` | Gen5::AgcDcbSetCxRegistersIndirect [só NID] | 1 | 0x1d0aff0 |
| `b-oySn+G2tE` | sceAgcAcbJumpGetSize | `implemented` | Gen5::AgcAcbJumpGetSize [só NID] | 1 | 0x1d0ae80 |
| `b5u0Jzm8TF8` | sceAgcDcbCopyDataGetSize | `implemented` | Gen5::AgcDcbCopyDataGetSize [só NID] | 1 | 0x1d0b610 |
| `bxGoVxpdSPQ` | sceAgcCbSetShRegisterRangeDirectGetSize | `implemented` | Gen5::AgcCbSetShRegisterRangeDirectGetSize [só NID] | 1 | 0x1d0ab00 |
| `cFazmnXpJOE` | sceAgcAcbEventWrite | `implemented` | Gen5::AgcAcbEventWrite [só NID] | 1 | 0x1d0aba2 |
| `cdDRpqcFGbU` | sceAgcDmaDataPatchSetSrcAddressOrOffsetOrImmediate | `implemented` | Gen5::AgcDmaDataPatchSetSrcAddressOrOffsetOrImmediate [só NID] | 1 | 0x1d0fcb0 |
| `cpCILPya5Zk` | sceAgcAcbPushMarker | `implemented` | Gen5::AgcAcbPushMarker [só NID] | 1 | 0x1d0ace0 |
| `cxPZ4Wgvdj8` | sceAgcDcbDrawIndirectGetSize | `implemented` | Gen5::AgcDcbDrawIndirectGetSize [só NID] | 1 | 0x1d0b690 |
| `d-6uF9sZDIU` | sceAgcSetCxRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetCxRegIndirectPatchAddRegisters [só NID] | 1 | 0x1d0fb90 |
| `e1DFTg+Sd8U` | sceAgcAcbJump | `implemented` | Gen5::AgcAcbJump [só NID] | 1 | 0x1d0abb7 |
| `eWaWyFegzgQ` |  | `implemented` | Gen5::AgcRewindPatchSetRewindState [só NID] | 1 | 0x1d0fc20 |
| `eZ4+17OQz4Q` | sceAgcAcbWriteData | `implemented` | Gen5::AgcAcbWriteData [só NID] | 1 | 0x1d0abc0 |
| `ewobAQeMo5k` | sceAgcAcbAcquireMemGetSize | `implemented` | Gen5::AgcAcbAcquireMemGetSize [só NID] | 1 | 0x1d0ae40 |
| `fPSCdQxgpSw` | sceAgcWriteDataPatchSetAddressOrOffset | `implemented` | Gen5::AgcWriteDataPatchSetAddressOrOffset [só NID] | 1 | 0x1d0fd50 |
| `fRG-JOH5+sI` | sceAgcSetUcRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetUcRegIndirectPatchSetNumRegisters [só NID] | 1 | 0x1d0fbb0 |
| `fd5Bp5tGTgo` |  | `implemented` | Gen5::AgcFuseShaderHalves_0200 [só NID] | 1 | 0x1d0a5bc |
| `h9z6+0hEydk` | sceAgcSuspendPoint | `implemented` | Gen5::AgcSuspendPoint [só NID] | 1 | 0x1d0a220 |
| `hEK26Wdny6s` | sceAgcDcbSetWorkloadComplete | `implemented` | Gen5::AgcDcbSetWorkloadComplete [só NID] | 1 | 0x1d0b530 |
| `hL7C0IRpWZI` | sceAgcCbQueueEndOfPipeActionGetSize | `implemented` | Gen5::AgcCbQueueEndOfPipeActionGetSize [só NID] | 1 | 0x1d0aaf0 |
| `htn36gPnBk4` | sceAgcAcbWaitRegMem | `implemented` | Gen5::AgcAcbWaitRegMem [só NID] | 1 | 0x1d0ac50 |
| `hvUfkUIQcOE` | sceAgcDcbSetUcRegistersIndirect | `implemented` | Gen5::AgcDcbSetUcRegistersIndirect [só NID] | 1 | 0x1d0b000 |
| `idlaArvdXEs` | sceAgcAcbWaitOnAddressGetSize | `implemented` | Gen5::AgcAcbWaitOnAddressGetSize [só NID] | 1 | 0x1d0aef0 |
| `k-JpyR2dYAM` |  | `implemented` | Gen5::AgcCondExecPatchSetEnd [só NID] | 1 | 0x1d0fbf0 |
| `kUlvghKs-mA` | sceAgcDcbDrawIndirectMulti | `implemented` | Gen5::AgcDcbDrawIndirectMulti [só NID] | 1 | 0x1d0b0b8 |
| `l4fM9K-Lyks` | sceAgcDcbSetIndexBuffer | `implemented` | Gen5::AgcDcbSetIndexBuffer [só NID] | 1 | 0x1d0b1f0 |
| `mR9j7+SfM34` | sceAgcDcbDrawIndexMultiInstancedGetSize | `implemented` | Gen5::AgcDcbDrawIndexMultiInstancedGetSize [só NID] | 1 | 0x1d0b6d0 |
| `n2fD4A+pb+g` | sceAgcCbSetShRegisterRangeDirect | `implemented` | Gen5::AgcCbSetShRegisterRangeDirect [só NID] | 1 | 0x1d0a9b0 |
| `n8vgpaQg6dA` | sceAgcSetRangePredication | `implemented` | Gen5::AgcSetRangePredication [só NID] | 1 | 0x1d0fc40 |
| `nCUgItdN2ms` | sceAgcSetShRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetShRegIndirectPatchSetNumRegisters [só NID] | 1 | 0x1d0fb50 |
| `nNlUtdDDvZ0` | sceAgcDcbSetShRegistersIndirectGetSize | `implemented` | Gen5::AgcDcbSetShRegistersIndirectGetSize [só NID] | 1 | 0x1d0b550 |
| `ou16V5hh5sg` | sceAgcDcbCondExecGetSize | `implemented` | Gen5::AgcDcbCondExecGetSize [só NID] | 1 | 0x1d0b5e0 |
| `ozKzBP4aki4` | sceAgcAcbCondExecGetSize | `implemented` | Gen5::AgcAcbCondExecGetSize [só NID] | 1 | 0x1d0ae70 |
| `p9tI+yTvx68` | sceAgcDcbWriteDataGetSize | `implemented` | Gen5::AgcDcbWriteDataGetSize [só NID] | 1 | 0x1d0b630 |
| `pFLArOT53+w` | sceAgcDcbSetShRegisterDirect | `implemented` | Gen5::AgcDcbSetShRegisterDirect [só NID] | 1 | 0x1d0b030 |
| `qMlfB1ZhMDc` | sceAgcDcbDrawIndexOffsetGetSize | `implemented` | Gen5::AgcDcbDrawIndexOffsetGetSize [só NID] | 1 | 0x1d0b680 |
| `qj7QZpgr9Uw` |  | `implemented` | Gen5::AgcDcbContextStateOp [só NID] | 1 | 0x1d0af40 |
| `qyM2bxYFPAk` | sceAgcAcbCondExec | `implemented` | Gen5::AgcAcbCondExec [só NID] | 1 | 0x1d0ab60 |
| `qzMN2XKGA4k` | sceAgcAcbCopyData | `implemented` | Gen5::AgcAcbCopyData [só NID] | 1 | 0x1d0ab70 |
| `s+VGAMDQ0AQ` | sceAgcGetDataPacketPayloadRange | `implemented` | Gen5::AgcGetDataPacketPayloadRange [só NID] | 1 | 0x1d0fc82 |
| `t7PlZ9nt5Lc` | sceAgcCbNopGetSize | `implemented` | Gen5::AgcCbNopGetSize [só NID] | 1 | 0x1d0aae0 |
| `tSBxhAPyytQ` | sceAgcDcbSetNumInstances | `implemented` | Gen5::AgcDcbSetNumInstances [só NID] | 1 | 0x1d0b210 |
| `u2T2DiA5hRI` | sceAgcDcbStallCommandBufferParser | `implemented` | Gen5::AgcDcbStallCommandBufferParser [só NID] | 1 | 0x1d0b220 |
| `vRoArM9zaIk` | sceAgcSetUcRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetUcRegIndirectPatchAddRegisters [só NID] | 1 | 0x1d0fbc0 |
| `vcmNN+AAXnY` | sceAgcSetCxRegIndirectPatchSetAddress | `implemented` | Gen5::AgcSetCxRegIndirectPatchSetAddress [só NID] | 1 | 0x1d0fb70 |
| `w4-d0n60hdo` | sceAgcDcbSetUcRegisterDirect | `implemented` | Gen5::AgcDcbSetUcRegisterDirect [só NID] | 1 | 0x1d0b010 |
| `w6Dj1VJt5qY` | sceAgcSetPacketPredication | `implemented` | Gen5::AgcSetPacketPredication [só NID] | 1 | 0x1d0fc30 |
| `w8HVkEeXPv8` | sceAgcDcbDispatchIndirectGetSize | `implemented` | Gen5::AgcDcbDispatchIndirectGetSize [só NID] | 1 | 0x1d0b650 |
| `wRbq6ZjNop4` |  | `implemented` | Gen5::AgcGetRegisterDefaults2Internal [só NID] | 1 | 0x1d09694 |
| `whb1RL7K4Ss` | sceAgcSetCxRegIndirectPatchSetNumRegisters | `implemented` | Gen5::AgcSetCxRegIndirectPatchSetNumRegisters [só NID] | 1 | 0x1d0fb80 |
| `xAeBOa0A3kk` | sceAgcAcbSetMarker | `implemented` | Gen5::AgcAcbSetMarker [só NID] | 1 | 0x1d0acc0 |
| `xSAR0LTcRKM` | sceAgcDcbJump | `implemented` | Gen5::AgcDcbJump [só NID] | 1 | 0x1d0af60 |
| `ypVBz4uPKcQ` | sceAgcDcbDrawIndexIndirectMulti | `implemented` | Gen5::AgcDcbDrawIndexIndirectMulti [só NID] | 1 | 0x1d0b0f8 |
| `z2duB-hHQSM` | sceAgcSetShRegIndirectPatchAddRegisters | `implemented` | Gen5::AgcSetShRegIndirectPatchAddRegisters [só NID] | 1 | 0x1d0fb60 |
| `zfcxg-ewMK8` | sceAgcDcbRewind | `implemented` | Gen5::AgcDcbRewind [só NID] | 1 | 0x1d0b240 |
| `ziVA3whp3p4` | sceAgcRewindPatchSetRewindState | `implemented` | Gen5::AgcRewindPatchSetRewindState [só NID] | 1 | 0x1d0fc10 |
| `1q1titRBL6o` | sceAgcDcbDrawIndirect | `implemented` | Gen5::AgcDcbDrawIndirect [só NID] | 0 |  |
| `B+aG9DUnTKA` | sceAgcDcbDrawIndexOffset | `implemented` | Gen5::AgcDcbDrawIndexOffset [só NID] | 0 |  |
| `CtB+A9-VxO0` | sceAgcDcbDispatchIndirect | `implemented` | Gen5::AgcDcbDispatchIndirect [só NID] | 0 |  |
| `D9sr1xGUriE` | sceAgcCreatePrimState | `implemented` | Gen5::AgcCreatePrimState [só NID] | 0 |  |
| `NKIzURsgV7I` | sceAgcGetGsOversubscription | `implemented` | Gen5::AgcGetGsOversubscription [só NID] | 0 |  |
| `Rlx+bykm0r0` | sceAgcDcbDrawIndexMultiInstanced | `implemented` | Gen5::AgcDcbDrawIndexMultiInstanced [só NID] | 0 |  |
| `Yw0jKSqop+E` | sceAgcDcbDrawIndexAuto | `implemented` | Gen5::AgcDcbDrawIndexAuto [só NID] | 0 |  |
| `dbOlWdppb4o` |  | `implemented` | Gen5::AgcCreateInterpolantMapping2 [só NID] | 0 |  |
| `dolOmWH+huQ` |  | `implemented` | Gen5::AgcGetFusedShaderSize [só NID] | 0 |  |
| `f3dg2CSgRKY` | sceAgcCreateShader | `implemented` | Gen5::AgcCreateShader [só NID] | 0 |  |
| `j3EtxFkSIhQ` | sceAgcAcbDispatchIndirect | `implemented` | Gen5::AgcAcbDispatchIndirect [só NID] | 0 |  |
| `k3GhuSNmBLU` | sceAgcCbDispatch | `implemented` | Gen5::AgcCbDispatch [só NID] | 0 |  |
| `q88lQ+GP5Yk` | sceAgcDcbDrawIndex | `implemented` | Gen5::AgcDcbDrawIndex [só NID] | 0 |  |
| `t1vNu082-jM` | sceAgcDcbDrawIndexIndirect | `implemented` | Gen5::AgcDcbDrawIndexIndirect [só NID] | 0 |  |
| `T6xuVw0KUJo` | sceAgcDebugRaiseException | `stub` | Gen5::AgcDebugRaiseException (return_constant) [só NID] | 1 | 0x1d0a51b |
| `G0jrLdvEqDw` |  | `missing` |  | 2 | 0x1d0b49b, 0x1d0b4d4 |
| `GXBlM-ekzrI` |  | `missing` |  | 2 | 0x1d0fae0, 0x1d0fb10 |
| `hFQ9pUxoLQ4` |  | `missing` |  | 2 | 0x1d0ad5b, 0x1d0b46b |
| `jt3pl7EN17o` |  | `missing` |  | 2 | 0x1d0b250, 0x1d0b264 |
| `q4VuU-QsLOE` |  | `missing` |  | 2 | 0x1d0ad8b, 0x1d0adc4 |
| `rP5xLdOf26k` |  | `missing` |  | 2 | 0x1d0fad0, 0x1d0fb07 |
| `rVOmPz2RBlg` |  | `missing` |  | 2 | 0x1d0adf3, 0x1d0ae10 |
| `szG7hz2yEhA` |  | `missing` |  | 2 | 0x1d0ac90, 0x1d0aca4 |
| `+u6dKSLWM2o` |  | `missing` |  | 1 | 0x1d0b760 |
| `0ZOG0jc9nRg` |  | `missing` |  | 1 | 0x1d0aee0 |
| `0o3VDdtA6nM` |  | `missing` |  | 1 | 0x1d0b282 |
| `1-gUn1PI4Sw` |  | `missing` |  | 1 | 0x1d0af20 |
| `1tB0xkLNjcw` |  | `missing` |  | 1 | 0x1d0b5c0 |
| `2ccJz9LQI+w` |  | `missing` |  | 1 | 0x1d0b620 |
| `6nths4DHNrs` |  | `missing` |  | 1 | 0x1d0a9f0 |
| `7toV+elXqNM` |  | `missing` |  | 1 | 0x1d0a910 |
| `8Kly1JrJUlw` |  | `missing` |  | 1 | 0x1d0acf0 |
| `9S4noWrUI0s` |  | `missing` |  | 1 | 0x1d0b700 |
| `AAeX-U5-P3M` |  | `missing` |  | 1 | 0x1d0a24d |
| `AFIh8SQkYlQ` |  | `missing` |  | 1 | 0x1d0b7f0 |
| `BYcSvEsINWU` |  | `missing` |  | 1 | 0x1d0b3e0 |
| `EJBA4dbmvfg` |  | `missing` |  | 1 | 0x1d0fda0 |
| `F8NLhWvFemI` |  | `missing` |  | 1 | 0x1d0af00 |
| `FcgdDM3MB+k` |  | `missing` |  | 1 | 0x1d0ae30 |
| `FneFypEDRgY` |  | `missing` |  | 1 | 0x1d0b540 |
| `FuVbkyKlf+s` |  | `missing` |  | 1 | 0x1d0aad0 |
| `GPbUp9jXQa8` |  | `missing` |  | 1 | 0x1d0ac60 |
| `J8YCgfKAMQs` |  | `missing` |  | 1 | 0x1d0fd10 |
| `JOWmDrl+j20` |  | `missing` |  | 1 | 0x1d0ab10 |
| `KjPeVduz6jU` |  | `missing` |  | 1 | 0x1d0b7e0 |
| `M0ttm8h7SKA` |  | `missing` |  | 1 | 0x1d0aea0 |
| `MDLD5Ly94Xk` |  | `missing` |  | 1 | 0x1d0a9c0 |
| `MMlmJAL7N5w` |  | `missing` |  | 1 | 0x1d0b710 |
| `N7M3+N-sBCw` |  | `missing` |  | 1 | 0x1d0b400 |
| `OQTgEXyihvA` |  | `missing` |  | 1 | 0x1d0a350 |
| `P1CugZ99Uzc` |  | `missing` |  | 1 | 0x1d0b7a0 |
| `PxKWV2fVAps` |  | `missing` |  | 1 | 0x1d0aeb0 |
| `QhPDD513V0w` |  | `missing` |  | 1 | 0x1d0b580 |
| `RTpj-tIlvZc` |  | `missing` |  | 1 | 0x1d0a370 |
| `SwI6QxqwAC0` |  | `missing` |  | 1 | 0x1d0a384 |
| `T9fjQIINoeE` |  | `missing` |  | 1 | 0x1d0fd30 |
| `TGEZzUWLbrc` |  | `missing` |  | 1 | 0x1d0ab30 |
| `UQGTw4xRlcM` |  | `missing` |  | 1 | 0x1d0b570 |
| `W0WEyog0f74` |  | `missing` |  | 1 | 0x1d0fd40 |
| `XKKuA6VkSRc` |  | `missing` |  | 1 | 0x1d0ab48 |
| `XN+Iuu7XsM8` |  | `missing` |  | 1 | 0x1d0b7b0 |
| `Y-5vneiBtzk` |  | `missing` |  | 1 | 0x1d0aec0 |
| `aP1Ki9G3++4` |  | `missing` |  | 1 | 0x1d0b5a0 |
| `ca4KPvp0qLQ` |  | `missing` |  | 1 | 0x1d0b720 |
| `d4NZIlguzv0` |  | `missing` |  | 1 | 0x1d0fd80 |
| `da1Sm8-QDoU` |  | `missing` |  | 1 | 0x1d0ae60 |
| `eAy8eGNsCuU` |  | `missing` |  | 1 | 0x1d0fd60 |
| `eCjKaqeeQ5s` |  | `missing` |  | 1 | 0x1d0aed0 |
| `ebixW91gpPw` |  | `missing` |  | 1 | 0x1d0ad10 |
| `gQkqkLttcpw` |  | `missing` |  | 1 | 0x1d0acb0 |
| `hcIxS8pmXF4` |  | `missing` |  | 1 | 0x1d0ae50 |
| `j4emHHndCPY` |  | `missing` |  | 1 | 0x1d0b730 |
| `mStuvI0zOtc` |  | `missing` |  | 1 | 0x1d0b6c0 |
| `mljzuGDZRQ4` |  | `missing` |  | 1 | 0x1d0b740 |
| `ms1xVoZ-Vwc` |  | `missing` |  | 1 | 0x1d0b790 |
| `n485EBnIWmk` |  | `missing` |  | 1 | 0x1d0fcd0 |
| `opR1JeJZCBU` |  | `missing` |  | 1 | 0x1d0ae20 |
| `oz6zQq1JwCE` |  | `missing` |  | 1 | 0x1d0b5d0 |
| `pYoKs3lPy88` |  | `missing` |  | 1 | 0x1d0b6a0 |
| `pxx-GoOSdw4` |  | `missing` |  | 1 | 0x1d0acd0 |
| `r98I08t+LOg` |  | `missing` |  | 1 | 0x1d0b6b0 |
| `rUuVjyR+Rd4` |  | `missing` |  | 1 | 0x1d0b6f4 |
| `tmy-+rBpspY` |  | `missing` |  | 1 | 0x1d0fd70 |
| `v3G+IipShZs` |  | `missing` |  | 1 | 0x1d0a360 |
| `vLrBL8DQiz8` |  | `missing` |  | 1 | 0x1d0b7d0 |
| `y5K5tPktiL8` |  | `missing` |  | 1 | 0x1d0fd90 |
| `yUBESvCCJ4I` |  | `missing` |  | 1 | 0x1d0ab20 |
| `yheJGN-ay+A` |  | `missing` |  | 1 | 0x1d0b7c0 |
| `zARR5aCmkoY` |  | `missing` |  | 1 | 0x1d0b3b0 |
| `zg6u-N6Otxs` |  | `missing` |  | 1 | 0x1d0b640 |
| `ICkECTBxrMw` |  | `missing` |  | 0 |  |
| `vieBRwlh1Lw` |  | `missing` |  | 0 |  |

### libSceAgcDriver

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `DL2RXaXOy88` | sceAgcDriverDeleteEqEvent | `implemented` | Gen5Driver::AgcDriverDeleteEqEvent [só NID] | 2 | 0x1d0a1ad, 0x1d0a1c5 |
| `w2rJhmD+dsE` | sceAgcDriverAddEqEvent | `implemented` | Gen5Driver::AgcDriverAddEqEvent [só NID] | 2 | 0x1d0a16d, 0x1d0a185 |
| `+T8Xo6LtFJI` |  | `implemented` | Gen5Driver::AgcDriverSubmitMultiDcbs [só NID] | 1 | 0x1d0a081 |
| `3AyTaWcF-H8` | sceAgcDriverRegisterWorkloadStream | `implemented` | Gen5::AgcDriverRegisterWorkloadStream [só NID] | 1 | 0x1d0a330 |
| `5CdQTZIQPxM` | sceAgcDriverGetEqEventType | `implemented` | Gen5Driver::AgcDriverGetEqEventType [só NID] | 1 | 0x1d0a1d4 |
| `6UzEidRZwkg` | sceAgcDriverSubmitMultiDcbs | `implemented` | Gen5Driver::AgcDriverSubmitMultiDcbs [só NID] | 1 | 0x1d0a06d |
| `AOLcoIkQDgM` | sceAgcDriverQueryResourceRegistrationUserMemoryRequirements | `implemented` | Gen5::AgcDriverQueryResourceRegistrationUserMemoryRequirements [só NID] | 1 | 0x1d0a390 |
| `AhGvpITrf4M` |  | `implemented` | Gen5Driver::AgcDriverSubmitDcb [só NID] | 1 | 0x1d0a009 |
| `F0Y42t-3e18` | sceAgcDriverInitResourceRegistration | `implemented` | Gen5::AgcDriverInitResourceRegistration [só NID] | 1 | 0x1d0a3a0 |
| `F0ZXt5q0ZTA` | sceAgcDriverGetDefaultOwner | `implemented` | Gen5::AgcDriverGetDefaultOwner [só NID] | 1 | 0x1d0a440 |
| `HF3YllT3mXU` | sceAgcDriverSubmitMultiAcbs | `implemented` | Gen5Driver::AgcDriverSubmitMultiAcbs [só NID] | 1 | 0x1d0a13e |
| `U9ueyEhSkF4` | sceAgcDriverRegisterDefaultOwner | `implemented` | Gen5Driver::AgcDriverRegisterDefaultOwner [só NID] | 1 | 0x1d0a430 |
| `UglJIZjGssM` | sceAgcDriverSubmitDcb | `implemented` | Gen5Driver::AgcDriverSubmitDcb [só NID] | 1 | 0x1d09ffa |
| `W5z4eZrjEas` | sceAgcDriverRegisterResource | `implemented` | Gen5::AgcDriverRegisterResource [só NID] | 1 | 0x1d0a3d0 |
| `X-Nm5KLREeg` | sceAgcDriverRegisterOwner | `implemented` | Gen5::AgcDriverRegisterOwner [só NID] | 1 | 0x1d0a3c0 |
| `ZLJk9r2+2Aw` | sceAgcDriverUnregisterOwnerAndResources | `implemented` | Gen5::AgcDriverUnregisterOwnerAndResources [só NID] | 1 | 0x1d0a410 |
| `Zw7uUVPulbw` | sceAgcDriverGetEqContextId | `implemented` | Gen5Driver::AgcDriverGetEqContextId [só NID] | 1 | 0x1d0a210 |
| `gSRnr79F8tQ` | sceAgcDriverSubmitAcb | `implemented` | Gen5Driver::AgcDriverSubmitAcb [só NID] | 1 | 0x1d0a0db |
| `pWLG7WOpVcw` | sceAgcDriverUnregisterResource | `implemented` | Gen5::AgcDriverUnregisterResource [só NID] | 1 | 0x1d0a400 |
| `uJziRsODk1c` | sceAgcDriverGetResourceRegistrationMaxNameLength | `implemented` | Gen5::AgcDriverGetResourceRegistrationMaxNameLength [só NID] | 1 | 0x1d0a3b0 |
| `Ddwk4gLT5j0` | sceAgcDriverIsCaptureInProgress | `stub` | Gen5Driver::AgcDriverIsCaptureInProgress (return_constant) [só NID] | 1 | 0x1d0a2a4 |
| `Xq5WmbwPTnQ` |  | `missing` |  | 2 | 0x1d0a260, 0x1d0a275 |
| `+TN0oRTBxJQ` |  | `missing` |  | 1 | 0x1d0a314 |
| `+iAOE3jCnkk` |  | `missing` |  | 1 | 0x1d0a2c0 |
| `5l3IfCFJxBs` |  | `missing` |  | 1 | 0x1d0a450 |
| `8F5j7U-Bq6s` |  | `missing` |  | 1 | 0x1d0a300 |
| `FOwvmNlFLjM` |  | `missing` |  | 1 | 0x1d0a290 |
| `ICaGtkEIXTk` |  | `missing` |  | 1 | 0x1d0a2f0 |
| `JQc0956gCf0` |  | `missing` |  | 1 | 0x1d0a3e0 |
| `LepGrgk77sM` |  | `missing` |  | 1 | 0x1d0a4c0 |
| `M9yBzRKkjPc` |  | `missing` |  | 1 | 0x1d0a460 |
| `NghWEUXp1qM` |  | `missing` |  | 1 | 0x1d0a480 |
| `SAfhzJPcjuk` |  | `missing` |  | 1 | 0x1d0a280 |
| `SCoAN5fYlUM` |  | `missing` |  | 1 | 0x1d0a420 |
| `VOMSpd9+vxU` |  | `missing` |  | 1 | 0x1d0a4a0 |
| `WHIOMbb+iIU` |  | `missing` |  | 1 | 0x1d0a2d0 |
| `chJWZcNSzjk` |  | `missing` |  | 1 | 0x1d0a2e0 |
| `emP3ckeS2uo` |  | `missing` |  | 1 | 0x1d0a3f0 |
| `ls4jfY576lw` |  | `missing` |  | 1 | 0x1d0a490 |
| `mXn+K9E-wOA` |  | `missing` |  | 1 | 0x1d0a4b0 |
| `n5ElQVYsU1A` |  | `missing` |  | 1 | 0x1d0a340 |
| `qspAL8bgcBY` |  | `missing` |  | 1 | 0x1d0a2b4 |
| `rI9lNAXPMIw` |  | `missing` |  | 1 | 0x1d0a470 |
| `rJUyMrDdxJg` |  | `missing` |  | 1 | 0x1d0a320 |

### libSceAjm

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `ezM2OhNxzck` | sceAjmBatchJobInitialize | `implemented` | Ajm::AjmBatchJobInitialize | 5 | 0x1de20f4, 0x1de217e, 0x1de21eb |
| `Q3dyFuwGn64` | sceAjmModuleRegister | `implemented` | Ajm::AjmModuleRegister | 4 | 0x1de1825, 0x1de1835, 0x1de1848 |
| `WfAiBW8Wcek` | sceAjmBatchErrorDump | `implemented` | Ajm::AjmBatchErrorDump | 4 | 0x1de1b2c, 0x1de1dfd, 0x1de24c3 |
| `5tOfnaClcqM` | sceAjmBatchStart | `implemented` | Ajm::AjmBatchStart | 2 | 0x1de1dca, 0x1de2492 |
| `RbLbuKv8zho` | sceAjmInstanceDestroy | `implemented` | Ajm::AjmInstanceDestroy | 2 | 0x1de1e9d, 0x1de263d |
| `-qLsfDAywIY` | sceAjmBatchWait | `implemented` | Ajm::AjmBatchWait | 1 | 0x1de1aec |
| `1t3ixYNXyuc` | sceAjmDecAt9ParseConfigData | `implemented` | Ajm::AjmDecAt9ParseConfigData | 1 | 0x1de209d |
| `3cAg7xN995U` | sceAjmBatchJobGetStatistics | `implemented` | Ajm::AjmBatchJobGetStatistics | 1 | 0x1de1da1 |
| `AxoDrINp4J8` | sceAjmInstanceCreate | `implemented` | Ajm::AjmInstanceCreate | 1 | 0x1de1f15 |
| `MmpF1XsQiHw` | sceAjmBatchInitialize | `implemented` | Ajm::AjmBatchInitialize | 1 | 0x1de1d24 |
| `SkEwpiu3tZg` | sceAjmBatchJobSetGaplessDecode | `implemented` | Ajm::AjmBatchJobSetGaplessDecode | 1 | 0x1de225a |
| `Z9NVCesiP0Q` | sceAjmBatchJobRunSplit | `implemented` | Ajm::AjmBatchJobRunSplit | 1 | 0x1de2412 |
| `dl+4eHSzUu4` | sceAjmInitialize | `implemented` | Ajm::AjmInitialize | 1 | 0x1de17e0 |
| `uJ3m8INuikg` | sceAjmBatchJobClearContext | `implemented` | Ajm::AjmBatchJobClearContext | 1 | 0x1de21a3 |
| `Wi7DtlLV+KI` | sceAjmModuleUnregister | `stub` | Ajm::AjmModuleUnregister (return_constant) | 4 | 0x1de1980, 0x1de1990, 0x1de199d |
| `MHur6qCsUus` | sceAjmFinalize | `stub` | Ajm::AjmFinalize (return_constant) | 1 | 0x1de19be |
| `bkRHEYG6lEM` | sceAjmMemoryRegister | `stub` | Ajm::AjmMemoryRegister (return_constant) | 1 | 0x1de30c3 |
| `pIpGiaYkHkM` | sceAjmMemoryUnregister | `stub` | Ajm::AjmMemoryUnregister (return_constant) | 1 | 0x1de317e |
| `eDFeTyi+G3Y` |  | `missing` |  | 2 | 0x1e2324f, 0x1e237c9 |

### libSceAmpr

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `I-Qm+MEso5c` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 6 | 0x1d35823, 0x1d3583c, 0x1d3585c |
| `jK+yuYCI7MA` |  | `implemented` | Ampr::CommandBufferWriteCounter | 6 | 0x1d35193, 0x1d351ad, 0x1d351cd |
| `ClnsFLLLcss` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 4 | 0x1d35750, 0x1d35772, 0x1d357a0 |
| `cQb8Zr8Q0Y0` |  | `implemented` | Ampr::CommandBufferWaitOnCounter | 4 | 0x1d350c0, 0x1d350dd, 0x1d35110 |
| `2Hw8gjMdwSY` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 2 | 0x1d35812, 0x1d358b5 |
| `4fgtGfXDrFc` |  | `implemented` | Ampr::MeasureCommandSizeWriteAddress | 2 | 0x1d357e2, 0x1d35885 |
| `8aI7R7WaOlc` |  | `implemented` | Ampr::CommandBufferConstructor | 2 | 0x1d35010, 0x1d35359 |
| `GuchCTefuZw` |  | `implemented` | Ampr::CommandBufferDestructor | 2 | 0x1d35020, 0x1d3539f |
| `H896Pt-yB4I` |  | `implemented` | Ampr::CommandBufferWriteKernelEventQueue | 2 | 0x1d351e3, 0x1d35286 |
| `JYd9g9L+TmE` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 2 | 0x1d35802, 0x1d358a5 |
| `bt3LHR9xjK4` |  | `implemented` | Ampr::CommandBufferWriteAddressFromTimeCounter | 2 | 0x1d35162, 0x1d35205 |
| `enZm-6GjWqw` |  | `implemented` | Ampr::CommandBufferWriteAddressFromCounterPair | 2 | 0x1d35182, 0x1d35225 |
| `gAtc79UTt5E` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 2 | 0x1d357f2, 0x1d35895 |
| `j0+3uJMxYJY` |  | `implemented` | Ampr::CommandBufferWriteAddress | 2 | 0x1d35152, 0x1d351f5 |
| `sSAUCCU1dv4` |  | `implemented` | Ampr::MeasureCommandSizeWriteKernelEventQueue | 2 | 0x1d35872, 0x1d35915 |
| `t4ExS+SwLjs` |  | `implemented` | Ampr::CommandBufferWriteAddressFromCounter | 2 | 0x1d35172, 0x1d35215 |
| `0BMj1hgG+kE` |  | `implemented` | Ampr::MeasureCommandSizeFixed32 | 1 | 0x1d35740 |
| `0RdLmAh7WVo` |  | `implemented` | Ampr::MeasureCommandSizeMarker | 1 | 0x1d359f0 |
| `3OfeY4pzDV0` |  | `implemented` | Ampr::MeasureCommandSizeMarkerWithColor | 1 | 0x1d359e0 |
| `4UkZbYKVF7c` |  | `implemented` | Ampr::CommandBufferConstructMarker | 1 | 0x1d352c0 |
| `4quckD2y7Pg` |  | `implemented` | Ampr::CommandBufferSetMarker | 1 | 0x1d35310 |
| `7nXGDGMXSqo` |  | `implemented` | Ampr::MeasureCommandSizeReadFileScatter | 1 | 0x1d35960 |
| `BVmR1H8l+XI` |  | `implemented` | Ampr::AprCommandBufferReadFileGatherScatter | 1 | 0x1d35431 |
| `DLfoNxTFNVk` |  | `implemented` | Ampr::CommandBufferWaitOnAddress | 1 | 0x1d350b0 |
| `DXmgc5op8Yw` |  | `implemented` | Ampr::MeasureCommandSizeReadFileGatherScatter | 1 | 0x1d35970 |
| `Eul7AGEpjLo` |  | `implemented` | Ampr::AprCommandBufferMapBegin | 1 | 0x1d35450 |
| `GmOguNIsuKk` |  | `implemented` | Ampr::CommandBufferConstructNop | 1 | 0x1d35290 |
| `GnxKOHEawhk` |  | `implemented` | Ampr::CommandBufferGetCurrentOffset | 1 | 0x1d350a0 |
| `Jg-AgkdJHkk` |  | `implemented` | Ampr::AprCommandBufferReadFileScatter | 1 | 0x1d3540e |
| `N-FSPA4S3nI` |  | `implemented` | Ampr::CommandBufferSetBuffer | 1 | 0x1d35040 |
| `NNIZ-FMyz3M` |  | `implemented` | Ampr::MeasureCommandSizeNop | 1 | 0x1d35920 |
| `RPCAhx-aabE` |  | `implemented` | Ampr::CommandBufferGetBufferBaseAddress | 1 | 0x1d35080 |
| `ULvXMDz56po` |  | `implemented` | Ampr::CommandBufferClearBuffer | 1 | 0x1d35050 |
| `VEDMaQmJZng` |  | `implemented` | Ampr::CommandBufferGetType | 1 | 0x1d35060 |
| `VGkEj4d6-Kg` |  | `implemented` | Ampr::MeasureCommandSizeMarker | 1 | 0x1d359d0 |
| `X169CE6G3Y4` |  | `implemented` | Ampr::AprCommandBufferMapEnd | 1 | 0x1d35470 |
| `Xp85BP3+BBI` |  | `implemented` | Ampr::MeasureCommandSizeNopWithData | 1 | 0x1d35930 |
| `YPxkUDhgoNI` |  | `implemented` | Ampr::AprCommandBufferResetGatherScatterState | 1 | 0x1d35448 |
| `a8uLzYY--tM` |  | `implemented` | Ampr::AprCommandBufferConstructor | 1 | 0x1d3536f |
| `bFEs0Gs6D2A` |  | `implemented` | Ampr::AprCommandBufferMapDirectBegin | 1 | 0x1d35460 |
| `baQO9ez2gL4` |  | `implemented` | Ampr::CommandBufferReset | 1 | 0x1d35030 |
| `dXPaz65HNmk` |  | `implemented` | Ampr::CommandBufferPushMarker | 1 | 0x1d35330 |
| `f12ObAMEi9A` |  | `implemented` | Ampr::CommandBufferPushMarkerWithColor | 1 | 0x1d35320 |
| `gzndltBEzWc` |  | `implemented` | Ampr::CommandBufferGetNumCommands | 1 | 0x1d35090 |
| `iwTNhyaemnw` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | 1 | 0x1d359b0 |
| `kdFImtTD0hc` |  | `implemented` | Ampr::MeasureAprCommandSizeMapBegin | 1 | 0x1d35990 |
| `mQ16-QdKv7k` |  | `implemented` | Ampr::AprCommandBufferReadFile | 1 | 0x1d353cf |
| `mZSbNJVJpV8` |  | `implemented` | Ampr::AprCommandBufferReadFileGather | 1 | 0x1d353ee |
| `mv0O8Zg0woU` |  | `implemented` | Ampr::CommandBufferPopMarker | 1 | 0x1d35340 |
| `pFQ9UHpO52s` |  | `implemented` | Ampr::CommandBufferNopWithData | 1 | 0x1d352b0 |
| `pbnNnahE8vk` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | 1 | 0x1d35a00 |
| `qesF88X4DRg` |  | `implemented` | Ampr::MeasureCommandSizeReadFileGather | 1 | 0x1d35950 |
| `qvbdJc7bG+s` |  | `implemented` | Ampr::MeasureAprCommandSizeMapDirectBegin | 1 | 0x1d359a0 |
| `rddQYXM0CjM` |  | `implemented` | Ampr::MeasureCommandSizePopMarker | 1 | 0x1d35980 |
| `sWbST0oQKsc` |  | `implemented` | Ampr::CommandBufferSetMarkerWithColor | 1 | 0x1d352ee |
| `tNn5WBkta60` |  | `implemented` | Ampr::CommandBufferNop | 1 | 0x1d352a0 |
| `tZDDEo2tE5k` |  | `implemented` | Ampr::CommandBufferGetSize | 1 | 0x1d35070 |
| `tmfr97+ED5I` |  | `implemented` | Ampr::MeasureCommandSizeMarkerWithColor | 1 | 0x1d359c0 |
| `vWU-odnS+fU` |  | `implemented` | Ampr::MeasureCommandSizeReadFile | 1 | 0x1d35940 |
| `Qs1xtplKo0U` |  | `stub` | Ampr::AprCommandBufferDestructor (return_constant) | 1 | 0x1d35391 |

### libSceAppContent

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `99b82IKXpH4` | sceAppContentAppParamGetInt | `implemented` | AppContent::AppContentAppParamGetInt | 1 | 0x883f6c |
| `R9lA82OraNs` | sceAppContentInitialize | `implemented` | AppContent::AppContentInitialize | 1 | 0x883e49 |

### libSceAudioOut

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `s1--uE9mBFw` | sceAudioOutClose | `implemented` | AudioOut::AudioOutClose | 3 | 0x1e4b618, 0x1e4b713, 0x1e4b844 |
| `QOQtbeDqsT4` | sceAudioOutOutput | `implemented` | AudioOut::AudioOutOutput | 2 | 0x1e4ba5e, 0x1e4baa8 |
| `b+uAV89IlxE` | sceAudioOutSetVolume | `implemented` | AudioOut::AudioOutSetVolume | 2 | 0x1e4b58f, 0x1e4b9af |
| `ekNvsT22rsY` | sceAudioOutOpen | `implemented` | AudioOut::AudioOutOpen | 1 | 0x1e4b556 |

### libSceAudioOut2

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `JK2wamZPzwM` | sceAudioOut2PortCreate | `implemented` | AudioOut2::AudioOut2PortCreate | 13 | 0x1dd8f7c, 0x1dd8fa0, 0x1dd905a |
| `8XTArSPyWHk` | sceAudioOut2PortSetAttributes | `implemented` | AudioOut2::AudioOut2PortSetAttributes | 9 | 0x1dd9e02, 0x1dd9ee1, 0x1dd9f9c |
| `cd+Rtw+D1x8` | sceAudioOut2PortDestroy | `implemented` | AudioOut2::AudioOut2PortDestroy | 8 | 0x1dd8fdb, 0x1dd909b, 0x1dd99da |
| `IaZXJ9M79uo` | sceAudioOut2UserDestroy | `implemented` | AudioOut2::AudioOut2UserDestroy | 4 | 0x1dd9ce9, 0x1dda67c, 0x1ddcf76 |
| `gatEUKG+Ea4` | sceAudioOut2PortGetState | `implemented` | AudioOut2::AudioOut2PortGetState | 4 | 0x1dda2a1, 0x1dda34e, 0x1dda38f |
| `R7d0F1g2qsU` | sceAudioOut2ContextGetQueueLevel | `implemented` | AudioOut2::AudioOut2ContextGetQueueLevel | 3 | 0x1dda461, 0x1ddbca0, 0x1ddbd01 |
| `xywYcRB7nbQ` | sceAudioOut2UserCreate | `implemented` | AudioOut2::AudioOut2UserCreate | 3 | 0x1dd921d, 0x1dda58f, 0x1ddccff |
| `0x6o1VVAYSY` | sceAudioOut2ContextCreate | `implemented` | AudioOut2::AudioOut2ContextCreate | 2 | 0x1dd9200, 0x1dda578 |
| `DImz2Ft9E2g` | sceAudioOut2GetSpeakerInfo | `implemented` | AudioOut2::AudioOut2GetSpeakerInfo | 2 | 0x1dda262, 0x1dda5eb |
| `on6ZH7Abo10` | sceAudioOut2ContextDestroy | `implemented` | AudioOut2::AudioOut2ContextDestroy | 2 | 0x1dd9d04, 0x1dda68c |
| `pDmme7Bgm6E` | sceAudioOut2ContextQueryMemory | `implemented` | AudioOut2::AudioOut2ContextQueryMemory | 2 | 0x1dd91ae, 0x1dda529 |
| `t5YrizufpQc` | sceAudioOut2ContextResetParam | `implemented` | AudioOut2::AudioOut2ContextResetParam | 2 | 0x1dd915a, 0x1dda511 |
| `PE2zHMqLSHs` | sceAudioOut2ContextAdvance | `implemented` | AudioOut2::AudioOut2ContextAdvance | 1 | 0x1dda208 |
| `aII9h5nli9U` | sceAudioOut2ContextPush | `implemented` | AudioOut2::AudioOut2ContextPush | 1 | 0x1dda231 |
| `g2tViFIohHE` | sceAudioOut2Initialize | `stub` | AudioOut2::AudioOut2Initialize (return_constant) | 2 | 0x1dd9146, 0x1dda4eb |

### libSceCommonDialog

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `BQ3tey0JmQM` | sceCommonDialogIsUsed | `stub` | CommonDialog::CommonDialogIsUsed (return_constant) | 1 | 0x909f8d |
| `uoUpLGNkygk` | sceCommonDialogInitialize | `stub` | CommonDialog::CommonDialogInitialize (return_constant) | 1 | 0x909d6e |

### libSceCoredump

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `8zLSfEfW5AU` | sceCoredumpRegisterCoredumpHandler | `implemented` | Coredump::sceCoredumpRegisterCoredumpHandler [só NID] | 1 | 0x84644b |
| `fFkhOgztiCA` | sceCoredumpUnregisterCoredumpHandler | `implemented` | Coredump::sceCoredumpUnregisterCoredumpHandler [só NID] | 1 | 0x846920 |
| `Dbbkj6YHWdo` |  | `missing` |  | 4 | 0x8466bf, 0x8466fe, 0x84674f |

### libSceFiber

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `uq2Y5BFz0PE` | sceFiberGetInfo | `implemented` | Fiber::FiberGetInfo | 3 | 0x842032, 0x13afeef, 0x13b015a |
| `JeNX5F-NzQU` | sceFiberFinalize | `implemented` | Fiber::FiberFinalize | 2 | 0x841c9f, 0x841cef |
| `B0ZX2hx9DMw` | sceFiberReturnToThread | `implemented` | Fiber::FiberReturnToThread | 1 | 0x841f75 |
| `JzyT91ucGDc` | sceFiberRename | `implemented` | Fiber::FiberRename | 1 | 0x84209b |
| `PFT2S-tJ7Uk` | sceFiberSwitch | `implemented` | Fiber::FiberSwitch | 1 | 0x841fcc |
| `a0LLrZWac0M` | sceFiberRun | `implemented` | Fiber::FiberRun | 1 | 0x841f2c |
| `asjUJJ+aa8s` | sceFiberOptParamInitialize | `implemented` | Fiber::FiberOptParamInitialize | 1 | 0x841de3 |
| `hVYD7Ou2pCQ` |  | `implemented` | Fiber::FiberInitialize | 1 | 0x841e43 |
| `p+zLIOg27zU` | sceFiberGetSelf | `implemented` | Fiber::FiberGetSelf | 1 | 0x13afbbd |

### libSceGameUpdate

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `LYVV9z8+owM` | sceGameUpdateCheck | `implemented` | LibGameUpdate::GameUpdateCheck | 1 | 0x8835a2 |
| `UvcvKaFvupA` | sceGameUpdateCreateRequest | `implemented` | LibGameUpdate::GameUpdateCreateRequest | 1 | 0x883554 |
| `YJtKLttI9fM` | sceGameUpdateInitialize | `implemented` | LibGameUpdate::GameUpdateInitialize | 1 | 0x882bd4 |
| `bcCyjHN5sn0` | sceGameUpdateDeleteRequest | `implemented` | LibGameUpdate::GameUpdateDeleteRequest | 1 | 0x8835f9 |
| `d1CNGEOaK28` | sceGameUpdateAbortRequest | `implemented` | LibGameUpdate::GameUpdateAbortRequest | 0 |  |

### libSceHttp

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `YuOW3dDAKYc` | sceHttpUriEscape | `implemented` | LibHttp::HttpUriEscape | 4 | 0x8710b4, 0x871110, 0x8711ea |
| `qe7oZ+v4PWA` | sceHttpDeleteRequest | `implemented` | Http::HttpDeleteRequest | 3 | 0x1d3dd5d, 0x1d3e4bf, 0x1d3e54a |
| `59tL1AQBb8U` | sceHttpUnsetEpoll | `implemented` | Http::HttpUnsetEpoll | 2 | 0x1d3dd54, 0x1d3e541 |
| `-xm7kZQNpHI` | sceHttpSetEpoll | `implemented` | Http::HttpSetEpoll | 1 | 0x1d3e2db |
| `0a2TBNfE3BU` | sceHttpGetStatusCode | `implemented` | Http::HttpGetStatusCode | 1 | 0x1d3de76 |
| `0gYjPTR-6cY` | sceHttpCreateTemplate | `implemented` | Http::HttpCreateTemplate | 1 | 0x1d3d2e0 |
| `1e2BNwI-XzE` | sceHttpSendRequest | `implemented` | Http::HttpSendRequest | 1 | 0x1d3de54 |
| `4I8vEpuEhZ8` | sceHttpDeleteTemplate | `implemented` | Http::HttpDeleteTemplate | 1 | 0x1d3d550 |
| `6381dWF+xsQ` | sceHttpCreateEpoll | `implemented` | Http::HttpCreateEpoll | 1 | 0x1d3db9b |
| `A9cVMUtEp4Y` | sceHttpInit | `implemented` | Http::HttpInit | 1 | 0x1d3d2bc |
| `Aeu5wVKkF9w` |  | `implemented` | Http::HttpCreateRequest | 1 | 0x1d3e28d |
| `EY28T2bkN7k` | sceHttpAddRequestHeader | `implemented` | Http::HttpAddRequestHeader | 1 | 0x1d3e31e |
| `Ik-KpLTlf7Q` | sceHttpTerm | `implemented` | Http::HttpTerm | 1 | 0x1d3d58d |
| `P6A3ytpsiYc` | sceHttpDeleteConnection | `implemented` | Http::HttpDeleteConnection | 1 | 0x1d3d4e8 |
| `PDxS48xGQLs` | sceHttpSetChunkedTransferEnabled | `implemented` | Http::HttpSetChunkedTransferEnabled | 1 | 0x1d3e2b4 |
| `htyBOoWeS58` | sceHttpsSetSslCallback | `implemented` | Http::HttpsSetSslCallback | 1 | 0x1d3d2fd |
| `hvG6GfBMXg8` | sceHttpAbortRequest | `implemented` | Http::HttpAbortRequest | 1 | 0x1d3e503 |
| `qISjDHrxONc` | sceHttpWaitRequest | `implemented` | Http::HttpWaitRequest | 1 | 0x1d3e0e1 |
| `qgxDBjorUxs` | sceHttpCreateConnectionWithURL | `implemented` | Http::HttpCreateConnectionWithURL | 1 | 0x1d3d85d |
| `s2-NPIvz+iA` | sceHttpSetNonblock | `implemented` | Http::HttpSetNonblock | 1 | 0x1d3e2cb |
| `wYhXVfS2Et4` | sceHttpDestroyEpoll | `implemented` | Http::HttpDestroyEpoll | 1 | 0x1d3dbc2 |
| `yuO2H2Uvnos` | sceHttpGetResponseContentLength | `implemented` | Http::HttpGetResponseContentLength | 1 | 0x1d3ded8 |
| `P5pdoykPYTk` |  | `missing` |  | 1 | 0x1d3dfbd |

### libSceHttp2

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `3JCe3lCbQ8A` | sceHttp2Init | `implemented` | LibHttp2::Http2Init | 3 | 0x87095a, 0x88de6f, 0x13aee14 |
| `YiBUtz-pGkc` | sceHttp2Term | `implemented` | LibHttp2::Http2Term | 3 | 0x870c07, 0x88dfe1, 0x13af1ea |
| `c8D9qIjo8EY` | sceHttp2DeleteRequest | `implemented` | LibHttp2::Http2DeleteRequest | 3 | 0x860923, 0x860963, 0x8714cf |
| `-rdXUi2XW90` | sceHttp2GetAllResponseHeaders | `implemented` | LibHttp2::Http2GetAllResponseHeaders | 2 | 0x860f9b, 0x86111a |
| `9XYJwCf3lEA` | sceHttp2GetStatusCode | `implemented` | LibHttp2::Http2GetStatusCode | 2 | 0x860f31, 0x86109d |
| `+wCt7fCijgk` | sceHttp2CreateTemplate | `implemented` | LibHttp2::Http2CreateTemplate | 1 | 0x8709df |
| `A+NVAFu4eCg` | sceHttp2SendRequestAsync | `implemented` | LibHttp2::Http2SendRequestAsync | 1 | 0x860a9f |
| `MOp-AUhdfi8` | sceHttp2WaitAsync | `implemented` | LibHttp2::Http2WaitAsync | 1 | 0x860e8c |
| `bGN-6zbo7ms` | sceHttp2ReadDataAsync | `implemented` | LibHttp2::Http2ReadDataAsync | 1 | 0x861740 |
| `mmyOCxQMVYQ` | sceHttp2CreateRequestWithURL | `implemented` | LibHttp2::Http2CreateRequestWithURL | 1 | 0x8712f6 |
| `nrPfOE8TQu0` | sceHttp2AddRequestHeader | `implemented` | LibHttp2::Http2AddRequestHeader | 1 | 0x87134f |
| `o0DBQpFE13o` | sceHttp2GetResponseContentLength | `implemented` | LibHttp2::Http2GetResponseContentLength | 1 | 0x861200 |
| `pDom5-078DA` | sceHttp2DeleteTemplate | `implemented` | LibHttp2::Http2DeleteTemplate | 1 | 0x870b9b |
| `IZ-qjhRqvjk` |  | `missing` |  | 1 | 0x860bf9 |

### libSceIme

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `PMVehSlfZ94` | sceImeKeyboardClose | `implemented` | ImeKeyboardClose | 2 | 0xb924de, 0xb9293d |
| `-4GCfYdNF1s` | sceImeUpdate | `implemented` | ImeUpdate | 1 | 0xb92813 |
| `eaFXjfJv3xs` | sceImeKeyboardOpen | `implemented` | ImeKeyboardOpen | 1 | 0xb92963 |

### libSceImeDialog

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `gyTyVn+bXMw` | sceImeDialogTerm | `implemented` | ImeDialog::ImeDialogTerm | 3 | 0x87e0e7, 0x140e563, 0x140e605 |
| `x01jxu+vxlc` | sceImeDialogGetResult | `implemented` | ImeDialog::ImeDialogGetResult | 3 | 0x87df80, 0x140e534, 0x140e5d4 |
| `IADmD4tScBY` | sceImeDialogGetStatus | `implemented` | ImeDialog::ImeDialogGetStatus | 2 | 0x87df5f, 0x140e504 |
| `NUeBrN7hzf0` | sceImeDialogInit | `implemented` | ImeDialog::ImeDialogInit | 2 | 0x87e988, 0x140e8d7 |
| `oBmw4xrmfKs` | sceImeDialogAbort | `implemented` | ImeDialog::ImeDialogAbort | 1 | 0x140e989 |

### libSceJpegEnc

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `K+rocojkr-I` |  | `missing` |  | 1 | 0x90bcba |
| `QbrU0cUghEM` |  | `missing` |  | 1 | 0x90be6b |
| `j1LyMdaM+C0` |  | `missing` |  | 1 | 0x90beee |
| `o6ZgXfFdWXQ` |  | `missing` |  | 1 | 0x90bc86 |

### libSceJson2

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `-hJRce8wn1U` |  | `implemented` | LibJson2::JsonMemAllocatorCtor [só NID] | 2 | 0x88db36, 0x88dd87 |
| `cK6bYHf-Q5E` |  | `implemented` | LibJson2::JsonInitializerCtor [só NID] | 2 | 0x88db4a, 0x88dd9b |
| `OcAgPxcq5Vk` |  | `stub` | LibJson2::JsonMemAllocatorDtor (empty) [só NID] | 4 | 0x88dc11, 0x88dc30, 0x88dca1 |
| `RujUxbr3haM` |  | `stub` | LibJson2::JsonInitializerDtor (empty) [só NID] | 2 | 0x88dc08, 0x88dc98 |
| `Cxwy7wHq4J0` |  | `stub` | LibJson2::JsonInitializerInitializeV1 (return_constant) [só NID] | 1 | 0x88de1a |

### libSceNet

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `2mKX2Spso7I` | sceNetSetsockopt | `implemented` | LibNet::NetSetsockopt | 13 | 0x876fb7, 0x13ff880, 0x13ff8b9 |
| `45ggEzakPJQ` | sceNetSocketClose | `implemented` | LibNet::NetSocketClose | 13 | 0x87685b, 0x13ee663, 0x13ee6c3 |
| `HQOwnfMGipQ` |  | `implemented` | LibNet::GetNetErrorAddr | 11 | 0x13efae5, 0x13eff3c, 0x14005e5 |
| `Inp1lfL+Jdw` | sceNetEpollDestroy | `implemented` | LibNet::NetEpollDestroy | 11 | 0x13eed9e, 0x13ef340, 0x13ff7c5 |
| `Q4qBuN-c0ZM` | sceNetSocket | `implemented` | LibNet::NetSocket | 9 | 0x876820, 0x13ff737, 0x167e254 |
| `304ooNZxWDY` | sceNetRecvfrom | `implemented` | LibNet::NetRecvfrom | 7 | 0x876e9c, 0x13efec2, 0x13efefd |
| `K7RlrTkI-mw` | sceNetPoolDestroy | `implemented` | LibNet::NetPoolDestroy | 6 | 0x870cdf, 0x88e00b, 0x8e6f38 |
| `bErx49PgxyY` | sceNetBind | `implemented` | LibNet::NetBind | 6 | 0x8768b6, 0x13fff38, 0x167e5a4 |
| `dgJBaeJnGpo` | sceNetPoolCreate | `implemented` | LibNet::NetPoolCreate | 6 | 0x87085d, 0x88de35, 0x8e6ccd |
| `Rbvt+5Y2iEw` | sceNetNtohs | `implemented` | LibNet::NetNtohs | 5 | 0x8765da, 0x876633, 0x13af8e7 |
| `ZVw46bsasAk` | sceNetEpollControl | `implemented` | LibNet::NetEpollControl | 5 | 0x13eed5a, 0x13ff781, 0x167e17c |
| `drjIbDbA7UQ` | sceNetEpollWait | `implemented` | LibNet::NetEpollWait | 5 | 0x13efabb, 0x14005bb, 0x167e633 |
| `hoOAofhhRvE` | sceNetGetsockname | `implemented` | LibNet::NetGetsockname | 5 | 0x87707d, 0x14013ae, 0x1401449 |
| `iWQWrwiSt8A` | sceNetHtons | `implemented` | LibNet::NetHtons | 5 | 0x8766c3, 0x167e58f, 0x1d3f263 |
| `8Kcp5d-q1Uo` | sceNetInetPton | `implemented` | LibNet::NetInetPton | 4 | 0x8766fb, 0x8e6deb, 0x167e4b1 |
| `9T2pDF2Ryqg` | sceNetHtonl | `implemented` | LibNet::NetHtonl | 4 | 0x8766b2, 0x1d3f24c, 0x1d3faf6 |
| `9wO9XrMsNhc` | sceNetRecv | `implemented` | LibNet::NetRecv | 4 | 0x876a09, 0x876d58, 0x167e3c5 |
| `OXXX4mUk3uk` | sceNetConnect | `implemented` | LibNet::NetConnect | 4 | 0x876916, 0x167e4f2, 0x167e8da |
| `SF47kB2MNTo` | sceNetEpollCreate | `implemented` | LibNet::NetEpollCreate | 4 | 0x13eed26, 0x13ff74d, 0x167e14a |
| `beRjXBn-z+o` | sceNetSend | `implemented` | LibNet::NetSend | 4 | 0x8769e9, 0x876ae8, 0x167e415 |
| `gvD1greCu0A` | sceNetSendto | `implemented` | LibNet::NetSendto | 4 | 0x876e36, 0x1401c50, 0x167ec27 |
| `pQGpHYopAIY` | sceNetNtohl | `implemented` | LibNet::NetNtohl | 4 | 0x8766a2, 0x13af8db, 0x1d40904 |
| `xphrZusl78E` | sceNetGetsockopt | `implemented` | LibNet::NetGetsockopt | 4 | 0x877025, 0x1d40c00, 0x1d40f36 |
| `9vA2aW+CHuA` | sceNetInetNtop | `implemented` | LibNet::NetInetNtop | 3 | 0x876786, 0x8e6d4d, 0x1d40d00 |
| `PIWqhn9oSxc` | sceNetAccept | `implemented` | LibNet::NetAccept | 3 | 0x876972, 0x167e70b, 0x1d40b90 |
| `kOj1HiAGE54` | sceNetListen | `implemented` | LibNet::NetListen | 3 | 0x8769c6, 0x167e5b6, 0x1d40b70 |
| `C4UgDHHPvdw` | sceNetResolverCreate | `implemented` | LibNet::NetResolverCreate | 2 | 0x8e6ce0, 0x1d40dc2 |
| `Nd91WaWmG2w` | sceNetResolverStartNtoa | `implemented` | LibNet::NetResolverStartNtoa | 2 | 0x8e6d30, 0x1d40de5 |
| `TSM6whtekok` | sceNetShutdown | `implemented` | LibNet::NetShutdown | 2 | 0x13ffe46, 0x1d40e80 |
| `kJlYH5uMAWI` | sceNetResolverDestroy | `implemented` | LibNet::NetResolverDestroy | 2 | 0x8e6f30, 0x1d40e42 |
| `hLuXdjHnhiI` | sceNetGetSockInfo | `implemented` | LibNet::NetGetSockInfo | 1 | 0x876f3e |
| `Apb4YDxKsRI` |  | `missing` |  | 1 | 0x8e6e0f |
| `w21YgGGNtBk` |  | `missing` |  | 1 | 0x1d40ed0 |
| `zJGf8xjFnQE` |  | `missing` |  | 1 | 0x1d40ff0 |

### libSceNetCtl

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `obuxdTiwkF8` | sceNetCtlGetInfo | `implemented` | NetCtl::NetCtlGetInfo | 6 | 0x6821a6, 0xb9499b, 0x13ed899 |
| `uBPlr0lbuiI` | sceNetCtlGetState | `implemented` | NetCtl::NetCtlGetState | 3 | 0xb94958, 0xb94b62, 0x140271b |
| `JO4yuTuMoKI` | sceNetCtlGetNatInfo | `implemented` | NetCtl::NetCtlGetNatInfo | 1 | 0x6821c2 |
| `Rqm2OnZMCz0` | sceNetCtlUnregisterCallback | `implemented` | NetCtl::NetCtlUnregisterCallback | 1 | 0x1403208 |
| `UJ+Z7Q+4ck0` | sceNetCtlRegisterCallback | `implemented` | NetCtl::NetCtlRegisterCallback | 1 | 0x14026cb |
| `iQw3iQPhvUQ` | sceNetCtlCheckCallback | `implemented` | NetCtl::NetCtlCheckCallback | 1 | 0x1402bc9 |
| `Z4wwCFiBELQ` | sceNetCtlTerm | `implemented` | NetCtl::NetCtlTerm | 0 |  |
| `gky0+oaNM4k` | sceNetCtlInit | `stub` | NetCtl::NetCtlInit (return_constant) | 4 | 0x87667a, 0x13ed689, 0x14040b1 |

### libSceNpCommerce

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `0aR2aWmQal4` | sceNpCommerceDialogInitialize | `implemented` | NpCommerceDialogInitialize | 1 | 0x63f44f |
| `DfSCDRA3EjY` | sceNpCommerceDialogOpen | `implemented` | NpCommerceDialogOpen | 1 | 0x63f9c6 |
| `LR5cwFMMCVE` | sceNpCommerceDialogUpdateStatus | `implemented` | NpCommerceDialogUpdateStatus | 1 | 0x63fa99 |
| `m-I92Ab50W8` | sceNpCommerceDialogTerminate | `implemented` | NpCommerceDialogTerminate | 1 | 0x63f464 |
| `r42bWcQbtZY` | sceNpCommerceDialogGetResult | `implemented` | NpCommerceDialogGetResult | 1 | 0x63fab9 |

### libSceNpCppWebApi

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `yD3I2CRcKmw` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 17 | 0x889cd3, 0x889ce6, 0x889cfa |
| `YHYfyQXdOLc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 14 | 0x88ad2c, 0x88ad41, 0x88ad55 |
| `vURZNQ8+cP0` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 5 | 0x889003, 0x889031, 0x889058 |
| `zOA2tHzOY8I` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 5 | 0x889962, 0x8899af, 0x8899d1 |
| `LTXWL-kuxGM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 3 | 0x889ef7, 0x88a04a, 0x88a06d |
| `N78k-Vryooc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 3 | 0x889aeb, 0x88a13d, 0x88a1c8 |
| `dVCh5JiPsSY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 3 | 0x8891c7, 0x889d0a, 0x889db4 |
| `yzYn2Pwc2LM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 3 | 0x889eef, 0x88a042, 0x88a065 |
| `0blWarRALu4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889b9e, 0x88a171 |
| `1JV7Mv590Cc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889a77, 0x889a8e |
| `7IgV8DBuzJQ` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x88a159, 0x88a165 |
| `AcHirYSl0HA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x8898fc, 0x889a28 |
| `GJu2OLJK5Eo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x8890d5, 0x889405 |
| `JYa01KuMqhA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889bef, 0x889c38 |
| `PGbdeeOVRRU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889eff, 0x88a075 |
| `SUOUmSmPy5E` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889e33, 0x889e59 |
| `Sdfm7eE3q80` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889146, 0x88915c |
| `Y295ygEccqk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x88db2d, 0x88dd7e |
| `syDD+xcUmEs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 2 | 0x889b52, 0x88a1e0 |
| `+3KiBw-4CQY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889e80 |
| `+631th1Z4DU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889ea8 |
| `+k2KKLVS+t8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888f8e |
| `-QZoGsAmbh8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889134 |
| `-xOoiK8HfDI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893e7 |
| `01ZGV2VvBPU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88adda |
| `0UNp2Ey5bw4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c890 |
| `0oIoKcDA0Fw` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c875 |
| `26SufKG5x4M` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c884 |
| `39c+H8bSITU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889164 |
| `3YR0qZiM9gI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8891a3 |
| `4TGeM5jD7x0` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88940d |
| `4tEx7tt+b7g` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88907b |
| `52AlYvq+dmk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88dec2 |
| `59ZoWcKl5v8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88adef |
| `5F7D2WLcblc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a1b4 |
| `5avJQwMJgsY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad49 |
| `7dqFi7Dvzgo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae61 |
| `8YtcWzYdIRs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893f3 |
| `8i5JWALfIoY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889016 |
| `8sRfYnV7XlA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8890ca |
| `8x++mBOUeso` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ddee |
| `9YWXkd3AZAk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c7fe |
| `9sti7vTvx2U` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8891e4 |
| `9y9YsMBbUq0` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88acb2 |
| `AS1rCnSRF1g` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889336 |
| `Bbc2pDcwP0g` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889908 |
| `BcrC80L8i0Q` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a1d4 |
| `Cb3IRwKPJPI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae6d |
| `D3tUMw-ZqcM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889b1a |
| `DNmJw98YzUU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae82 |
| `DeFsyDHokeY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88adb0 |
| `E8BmtbByVKs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c798 |
| `EOKBl05t-hk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88aca1 |
| `Er5RROJCXYo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889cdb |
| `F5yaU6TEU8g` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889ae0 |
| `FQO2aJ3rhKI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888faf |
| `G46aDJx5Qx8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae19 |
| `GX4DLMQ9488` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889b38 |
| `IAkGC4cv3zs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c898 |
| `IQOtjPPUJZM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888f85 |
| `KD0NkSaIi1M` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae8b |
| `KXllpv1tR48` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889a9d |
| `KanXmz-cpzE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad9b |
| `Kg1U7CAbtio` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893ac |
| `KnCMTTJWLdg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889d84 |
| `LMpRWV5XyrQ` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889063 |
| `LwGrNk25QbE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893df |
| `MVExpBYTEow` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889917 |
| `Ma7+aWJsXow` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a1a7 |
| `MkGUMQt7MBE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889cee |
| `MkSmI8WCSvM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a6a1 |
| `Mnp3qDir4NU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a198 |
| `N0V2-p-0hAM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a874 |
| `O+VoB8m5MXA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88903c |
| `OV+MKKnbEYM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8890b8 |
| `OfSm8N8i+XA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893c7 |
| `OlMxxnDBfEg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8891bf |
| `P5mDlGPLSUU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a640 |
| `PmMi+EcpbpM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889ebc |
| `Q0fKqfQeXnI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8890f5 |
| `QXLG4UDWLEI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8898e8 |
| `QxB6IX2hOYg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889186 |
| `R5QhFOlpzjo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893d3 |
| `RM35a8uFre4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888fe8 |
| `TJz8sDUa6n4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a65c |
| `UYPxv8MIzGo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88deac |
| `V2NelZNoJwI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c7b6 |
| `VhWD7ylSQu8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88adc5 |
| `W12G2P+s074` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889bad |
| `WGKQ359T744` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889c29 |
| `X1SYe8TIGOc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889dac |
| `X2lVKLlddME` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889bb5 |
| `XWJpJef97fM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a87c |
| `XtFyTKi22Sc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a1bc |
| `Y+pTVRiUcHo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a859 |
| `Y+u-l+LxGIs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88910f |
| `YAtVGPtThx8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae4a |
| `YKVixVJQoXU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8899dc |
| `ZkSM1nh5zM8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88acbb |
| `bEwJsewIngA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889943 |
| `bVJ-1ExjYco` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae04 |
| `br6GL-f3CQg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8899ba |
| `c00bHjdQxuc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888fbb |
| `cJ8md8EbvrI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad86 |
| `cq65J5rCEwE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad72 |
| `ctghP7Sf6+c` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889b6f |
| `dcbbhKIZCDA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88914e |
| `eyiQGHPBIKI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a64c |
| `fJ9329XKPPA` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889ed0 |
| `fhRcPQVoEqM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a868 |
| `g9FmpQw2M-U` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a052 |
| `gTiHp+M4wFM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888fa3 |
| `gp3soLZ1nu0` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ac98 |
| `gxlgckSr7z4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889ab3 |
| `h8K-pa8owbg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889d98 |
| `hH7KHku1lqs` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c7d9 |
| `hQdNOFlDedY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad5d |
| `hjzv6lEAIuI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad06 |
| `iiYZCXOo7Go` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae93 |
| `jTcdCjMNdrk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ace7 |
| `jX6HZUWtU8g` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8891fc |
| `jaVd5xkK0tU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889a6f |
| `jfCufYd0-+s` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889099 |
| `kRXjOtU-NTI` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae35 |
| `kVGz48sqNJM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c83b |
| `khThzVltokg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88996d |
| `kpbW7Dr44Gc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88c78c |
| `lfUiDOAsDoo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad34 |
| `mVKcd5NwiWE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893fc |
| `mqXwMzp+7pE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888f7c |
| `ncIcckZh0rk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a6ef |
| `o6kFQQ6TGg4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ad1b |
| `oTirsxQpqj0` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88df86 |
| `owrpOxU0eoE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889aa8 |
| `pBSgMrf0tnM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889a02 |
| `plUh+Axzi30` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a179 |
| `pq7sFJ6E6Sg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889415 |
| `ptE7eJxWp0c` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889be4 |
| `qGwknHP6ohM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8891b7 |
| `qnvk932UxYg` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889c48 |
| `rBNBuzCGsLQ` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888fcb |
| `rVdu+F4JFC4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x888f97 |
| `rdEN7D3ZN1E` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889bd2 |
| `s7YtGdt8Sg4` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88accb |
| `s8GYZ2aPoTU` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889a5f |
| `sCnkOGMZjH8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88a67c |
| `sSr4mR33SaY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8893bb |
| `tJMAm9ZBelo` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x88ae79 |
| `u1wbCugKzYQ` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889d02 |
| `v+tXF9ppYiQ` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889b8a |
| `wJWqKZOj4Ts` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889a86 |
| `x5fMr5644iE` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889d70 |
| `xZ2OF6809Mk` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889b4a |
| `ysAnsG6EfkM` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889bc0 |
| `z3id8GlN+Hc` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889927 |
| `zfvBGft4XrY` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x8898dc |
| `zk7Es711EV8` |  | `provided_by_game_module` | sce_module/libSceNpCppWebApi.prx | 1 | 0x889e94 |

### libSceNpEntitlementAccess

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `TFyU+KFBv54` | sceNpEntitlementAccessGetAddcontEntitlementInfoList | `implemented` | LibNpEntitlementAccess::NpEntitlementAccessGetAddcontEntitlementInfoList | 2 | 0x87eddc, 0x87ef03 |
| `jO8DM8oyego` | sceNpEntitlementAccessInitialize | `implemented` | LibNpEntitlementAccess::NpEntitlementAccessInitialize | 1 | 0x87efef |

### libSceNpGameIntent

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `rPl0INNc-M8` | sceNpGameIntentGetPropertyValueString | `implemented` | LibNpGameIntent::NpGameIntentGetPropertyValueString | 5 | 0x884a1e, 0x884a41, 0x884b2c |
| `jEIXUAr9XE8` | sceNpGameIntentReceiveIntent | `implemented` | LibNpGameIntent::NpGameIntentReceiveIntent | 1 | 0x884927 |
| `m87BHxt-H60` | sceNpGameIntentInitialize | `stub` | LibNpGameIntent::NpGameIntentInitialize (return_constant) | 1 | 0x883e20 |

### libSceNpManager

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `XDncXQIJUSk` | sceNpGetOnlineId | `implemented` | NpManager::NpGetOnlineId | 5 | 0x664905, 0x682308, 0x8f81fc |
| `S7QTn72PrDw` | sceNpDeleteRequest | `implemented` | NpManager::NpDeleteRequest | 4 | 0x63f553, 0x63f685, 0x63f78f |
| `rbknaUjpqWo` | sceNpGetAccountIdA | `implemented` | NpManager::NpGetAccountIdA | 4 | 0x6648f6, 0x6822ee, 0x8f81ed |
| `3Tcz5bNCfZQ` | sceNpGetAccountLanguage2 | `implemented` | NpManager::NpGetAccountLanguage2 | 1 | 0x682345 |
| `3Zl8BePTh9Y` | sceNpCheckCallback | `implemented` | NpManager::NpCheckCallback | 1 | 0x13a56f4 |
| `Ec63y59l9tw` | sceNpSetNpTitleId | `implemented` | NpManager::NpSetNpTitleId | 1 | 0x8841b3 |
| `GpLQDNKICac` | sceNpCreateRequest | `implemented` | NpManager::NpCreateRequest | 1 | 0x68232f |
| `JT+t00a3TxA` | sceNpGetAccountCountryA | `implemented` | NpManager::NpGetAccountCountryA | 1 | 0x682322 |
| `O80NrhUOPGY` | sceNpCheckPremium | `implemented` | NpManager::NpCheckPremium | 1 | 0x63f606 |
| `OzKvTvg3ZYU` | sceNpAbortRequest | `implemented` | NpManager::NpAbortRequest | 1 | 0x63f933 |
| `eQH7nWPcAgc` | sceNpGetState | `implemented` | NpManager::NpGetState | 1 | 0x140291c |
| `eiqMCt9UshI` | sceNpCreateAsyncRequest | `implemented` | NpManager::NpCreateAsyncRequest | 1 | 0x63f4c1 |
| `qQJfO8HAiaY` | sceNpRegisterStateCallbackA | `implemented` | NpManager::NpRegisterStateCallbackA | 1 | 0x1402701 |
| `uqcPJLWL08M` | sceNpPollAsync | `implemented` | NpManager::NpPollAsync | 1 | 0x63f774 |
| `M3wFXbYQtAA` |  | `stub` | NpManager::NpUnregisterStateCallback (return_constant) | 1 | 0x1403213 |
| `P6piso307SE` |  | `missing` |  | 1 | 0x13a4b17 |

### libSceNpSessionSignaling

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `ysmw6J-P8Ak` | sceNpSessionSignalingInitialize | `stub` | NpSessionSignalingInitialize (return_constant) | 1 | 0x13aefa4 |
| `yJw2m6UWDYU` |  | `missing` |  | 2 | 0x13af7e8, 0x13af868 |
| `CqJuNXo5yiM` |  | `missing` |  | 1 | 0x13af087 |
| `Z9Q9LzQDXf0` |  | `missing` |  | 1 | 0x13afa01 |
| `aBuX0PX-T7I` |  | `missing` |  | 1 | 0x13af3f9 |
| `cQkBH-pXhF0` |  | `missing` |  | 1 | 0x13b215d |
| `r4XacqHvkn4` |  | `missing` |  | 1 | 0x13ba5ff |

### libSceNpUniversalDataSystem

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `W-0xwY0ZMjw` | sceNpUniversalDataSystemDestroyEventPropertyArray | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemDestroyEventPropertyArray | 24 | 0x652d80, 0x652e9a, 0x6531a7 |
| `wG+84pnNIuo` | sceNpUniversalDataSystemDestroyEvent | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemDestroyEvent | 15 | 0x650c58, 0x652ea8, 0x6532e4 |
| `p+GcLqwpL9M` | sceNpUniversalDataSystemCreateEvent | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemCreateEvent | 14 | 0x650ab2, 0x652cd8, 0x6530bf |
| `Hm7qubT3b70` | sceNpUniversalDataSystemCreateEventPropertyArray | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemCreateEventPropertyArray | 12 | 0x652d1f, 0x653106, 0x65386e |
| `Wxbg5x3pTXA` | sceNpUniversalDataSystemEventPropertyObjectSetArray | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyObjectSetArray | 12 | 0x652d6a, 0x653151, 0x6538cc |
| `MfDb+4Nln64` | sceNpUniversalDataSystemEventPropertyObjectSetString | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyObjectSetString | 11 | 0x652cf3, 0x652d0e, 0x6530da |
| `4llLk7YJRTE` | sceNpUniversalDataSystemEventPropertyArraySetString | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyArraySetString | 8 | 0x653898, 0x653908, 0x654278 |
| `YE4dbtbz6OE` | sceNpUniversalDataSystemEventPropertyObjectSetInt32 | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyObjectSetInt32 | 8 | 0x650ac9, 0x650ae4, 0x650aff |
| `JmgwKm96Lq4` | sceNpUniversalDataSystemEventPropertyArraySetFloat32 | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyArraySetFloat32 | 6 | 0x652d35, 0x652d4c, 0x65311c |
| `su7jW3VDDb4` | sceNpUniversalDataSystemGetMemoryStat | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemGetMemoryStat | 2 | 0x650143, 0x65058c |
| `5zBnau1uIEo` | sceNpUniversalDataSystemCreateContext | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemCreateContext | 1 | 0x88d00c |
| `AzD4irAcKE4` | sceNpUniversalDataSystemEventPropertyObjectSetUInt32 | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyObjectSetUInt32 | 1 | 0x654ebe |
| `CzkKf7ahIyU` | sceNpUniversalDataSystemPostEvent | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemPostEvent | 1 | 0x88d4c2 |
| `XY14n3jNIpE` | sceNpUniversalDataSystemEventPropertyArraySetObject | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyArraySetObject | 1 | 0x655154 |
| `hT0IAEvN+M0` | sceNpUniversalDataSystemCreateHandle | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemCreateHandle | 1 | 0x88d07a |
| `kKUH0Viib3c` | sceNpUniversalDataSystemDestroyEventPropertyObject | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemDestroyEventPropertyObject | 1 | 0x655165 |
| `s6W4Zl4Slgk` | sceNpUniversalDataSystemCreateEventPropertyObject | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemCreateEventPropertyObject | 1 | 0x655103 |
| `sjaobBgqeB4` | sceNpUniversalDataSystemInitialize | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemInitialize | 1 | 0x88cf97 |
| `tpFJ8LIKvPw` | sceNpUniversalDataSystemRegisterContext | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemRegisterContext | 1 | 0x88d0e9 |
| `xvsP5Yz6FmY` | sceNpUniversalDataSystemEventPropertyObjectSetUInt64 | `implemented` | LibNpUniversalDataSystem::NpUniversalDataSystemEventPropertyObjectSetUInt64 | 1 | 0x654ea1 |

### libSceNpWebApi2

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `+o9816YQhqQ` | sceNpWebApi2Initialize | `implemented` | LibNpWebApi2::NpWebApi2Initialize | 2 | 0x88de89, 0x13aee90 |
| `MsaFhR+lPE4` | sceNpWebApi2PushEventCreateFilter | `implemented` | LibNpWebApi2::NpWebApi2PushEventCreateFilter | 2 | 0x13bc9dd, 0x13bcf4d |
| `OOY9+ObfKec` | sceNpWebApi2ReadData | `implemented` | LibNpWebApi2::NpWebApi2ReadData | 2 | 0x13bc511, 0x13bc557 |
| `bEvXpcEk200` | sceNpWebApi2Terminate | `implemented` | LibNpWebApi2::NpWebApi2Terminate | 2 | 0x88dfcc, 0x13af178 |
| `sk54bi6FtYM` | sceNpWebApi2CreateUserContext | `implemented` | LibNpWebApi2::NpWebApi2CreateUserContext | 2 | 0x88e08b, 0x13a8673 |
| `vvzWO-DvG1s` | sceNpWebApi2DeleteRequest | `implemented` | LibNpWebApi2::NpWebApi2DeleteRequest | 2 | 0x13bc33c, 0x13bc419 |
| `3EI-OSJ65Xc` | sceNpWebApi2CreateRequest | `implemented` | LibNpWebApi2::NpWebApi2CreateRequest | 1 | 0x13bbedd |
| `WV1GwM32NgY` | sceNpWebApi2PushEventCreateHandle | `implemented` | LibNpWebApi2::NpWebApi2PushEventCreateHandle | 1 | 0x13a869d |
| `fY3QqeNkF8k` | sceNpWebApi2PushEventRegisterCallback | `implemented` | LibNpWebApi2::NpWebApi2PushEventRegisterCallback | 1 | 0x13bca10 |
| `lQOCF84lvzw` | sceNpWebApi2SendRequest | `implemented` | LibNpWebApi2::NpWebApi2SendRequest | 1 | 0x13bc1d3 |
| `9X9+cneTGUU` | sceNpWebApi2DeleteUserContext | `stub` | LibNpWebApi2::NpWebApi2DeleteUserContext (return_constant) | 5 | 0x88dfa3, 0x88e224, 0x13a62d7 |
| `fIATVMo4Y1w` | sceNpWebApi2PushEventDeleteHandle | `stub` | LibNpWebApi2::NpWebApi2PushEventDeleteHandle (return_constant) | 3 | 0x13a6254, 0x13a89f1, 0x13a99d0 |
| `QafxeZM3WK4` | sceNpWebApi2PushEventDeletePushContext | `stub` | LibNpWebApi2::NpWebApi2PushEventDeletePushContext (return_constant) | 2 | 0x13bd4f2, 0x13bd6a9 |
| `egOOvrnF6mI` | sceNpWebApi2AddHttpRequestHeader | `stub` | LibNpWebApi2::NpWebApi2AddHttpRequestHeader (return_constant) | 2 | 0x13bbfec, 0x13bc15c |
| `KJdPcOGmK58` |  | `missing` |  | 4 | 0x13bcc10, 0x13bcdd7, 0x13bd180 |
| `AAj9X+4aGYA` |  | `missing` |  | 1 | 0x13bd473 |
| `NNVf18SlbT8` |  | `missing` |  | 1 | 0x13bd43a |
| `PmyrbbJSFz0` |  | `missing` |  | 1 | 0x13bd2d4 |
| `hOnIlcGrO6g` |  | `missing` |  | 1 | 0x13bcd64 |
| `lxtHJMwBsaU` |  | `missing` |  | 1 | 0x13bcf80 |

### libScePad

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `2JgFB2n9oUM` | scePadSetTriggerEffect | `implemented` | Controller::PadSetTriggerEffect | 5 | 0xb92fda, 0xb93042, 0xb930a2 |
| `q1cHNfGycLI` | scePadRead | `implemented` | Controller::PadRead | 3 | 0xb93403, 0x11a8408, 0x11a8467 |
| `clVvL4ZDntw` | scePadSetMotionSensorState | `implemented` | Controller::PadSetMotionSensorState | 2 | 0xb92e7c, 0xb92ea8 |
| `hv1luiJrqQM` | scePadInit | `implemented` | Controller::PadInit | 2 | 0xb92326, 0x11a833b |
| `xk0AcarP3V4` | scePadOpen | `implemented` | Controller::PadOpen | 2 | 0xb92de8, 0x11a8356 |
| `6ncge5+l5Qs` | scePadClose | `implemented` | Controller::PadClose | 1 | 0xb92e43 |
| `RR4novUEENY` | scePadSetLightBar | `implemented` | Controller::PadSetLightBar | 1 | 0xb92f6f |
| `YndgXqQVV7c` | scePadReadState | `implemented` | Controller::PadReadState | 1 | 0xb93561 |
| `gjP9-KQzoUk` | scePadGetControllerInformation | `implemented` | Controller::PadGetControllerInformation | 1 | 0xb93493 |
| `u1GRHp+oWoY` | scePadGetHandle | `implemented` | Controller::PadGetHandle | 1 | 0x11a8379 |
| `yFVnOdGxvZY` | scePadSetVibration | `implemented` | Controller::PadSetVibration | 1 | 0xb92f15 |

### libScePlayGo

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `uWIYLFkkwqk` | scePlayGoGetLocus | `implemented` | PlayGo::PlayGoGetLocus | 3 | 0x87f75d, 0x87faf0, 0x880e00 |
| `HVAa744ecdw` | scePlayGoPrefetchOptionalChunk | `implemented` | PlayGo::PlayGoPrefetchOptionalChunk | 2 | 0x87fda2, 0x88006c |
| `IfiN+-oeVWI` | scePlayGoGetSupportedOptionalChunk | `implemented` | PlayGo::PlayGoGetSupportedOptionalChunk | 2 | 0x87fd7e, 0x880045 |
| `g4AZyxpSAlA` | scePlayGoGetOptionalChunk | `implemented` | PlayGo::PlayGoGetOptionalChunk | 2 | 0x87fd6a, 0x880034 |
| `-Q1-u1a7p0g` | scePlayGoPrefetch | `implemented` | PlayGo::PlayGoPrefetch | 1 | 0x880b5c |
| `-RJWNMK3fC8` | scePlayGoGetProgress | `implemented` | PlayGo::PlayGoGetProgress | 1 | 0x88049a |
| `4AAcTU9R3XM` | scePlayGoSetInstallSpeed | `implemented` | PlayGo::PlayGoSetInstallSpeed | 1 | 0x880959 |
| `M1Gma1ocrGE` | scePlayGoOpen | `implemented` | PlayGo::PlayGoOpen | 1 | 0x87f64a |
| `Nn7zKwnA5q0` | scePlayGoGetToDoList | `implemented` | PlayGo::PlayGoGetToDoList | 1 | 0x880fb0 |
| `rvBSfTimejE` | scePlayGoGetInstallSpeed | `implemented` | PlayGo::PlayGoGetInstallSpeed | 1 | 0x87f67c |
| `ts6GlZOKRrE` | scePlayGoInitialize | `implemented` | PlayGo::PlayGoInitialize | 1 | 0x87f5bb |
| `v6EZ-YWRdMs` | scePlayGoGetEta | `implemented` | PlayGo::PlayGoGetEta | 1 | 0x880482 |

### libScePngEnc

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `7aGTPfrqT9s` | scePngEncCreate | `implemented` | PngEnc::PngEncCreate | 1 | 0x90b855 |
| `9030RnBDoh4` | scePngEncQueryMemorySize | `implemented` | PngEnc::PngEncQueryMemorySize | 1 | 0x90b821 |
| `RUrWdwTWZy8` | scePngEncDelete | `implemented` | PngEnc::PngEncDelete | 1 | 0x90ba9b |
| `xgDjJKpcyHo` | scePngEncEncode | `implemented` | PngEnc::PngEncEncode | 1 | 0x90ba18 |

### libScePosix

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `2Z+PpY6CaJg` | pthread_mutex_unlock | `implemented` | Posix::pthread_mutex_unlock | 449 | 0x15b7baa, 0x15b7d92, 0x15b80d7 |
| `7H0iTOciTLo` | pthread_mutex_lock | `implemented` | Posix::pthread_mutex_lock | 342 | 0x15b7b0d, 0x15b7cad, 0x15b7e6d |
| `K-jXhbt2gn4` | pthread_mutex_trylock | `implemented` | Posix::pthread_mutex_trylock | 342 | 0x15b7ae3, 0x15b7c83, 0x15b7e43 |
| `ltCfaGr2JGE` | pthread_mutex_destroy | `implemented` | Posix::pthread_mutex_destroy | 67 | 0x15b7a34, 0x15d86e2, 0x15d9e4d |
| `TUuiYS2kE8s` | shutdown | `implemented` | Posix::shutdown | 4 | 0x13ee648, 0x13ee6a8, 0x13ee828 |
| `fFxGkxF2bVo` | setsockopt | `implemented` | Posix::setsockopt | 4 | 0x13eee59, 0x13eee92, 0x13f04fd |
| `EotR8a3ASf4` | pthread_self | `implemented` | Posix::pthread_self | 3 | 0x1e6e336, 0x1e6e579, 0x1e6e716 |
| `T8fER+tIGgk` | select | `implemented` | Posix::select | 3 | 0x876aba, 0x876c3b, 0x876d2a |
| `4n51s0zEf0c` | inet_pton | `implemented` | Posix::inet_pton | 2 | 0x13d79af, 0x13d7a52 |
| `6O8EwYOgH9Y` | getsockopt | `implemented` | Posix::getsockopt | 2 | 0x13f038d, 0x1400f3a |
| `FIs3-UQT9sg` | pthread_getschedparam | `implemented` | Posix::pthread_getschedparam | 2 | 0x1e6e346, 0x1e6e589 |
| `HF7lK46xzjY` | pthread_mutexattr_destroy | `implemented` | Posix::pthread_mutexattr_destroy | 2 | 0x15d8e36, 0x15d8ef1 |
| `KuOmgKoqCdY` | bind | `implemented` | Posix::bind | 2 | 0x13ee796, 0x13ef467 |
| `RenI1lL1WFk` | getsockname | `implemented` | Posix::getsockname | 2 | 0x13f078e, 0x13f0829 |
| `TU-d9PfIHPM` | socket | `implemented` | Posix::socket | 2 | 0x13ee783, 0x13eed10 |
| `5jRCs2axtr4` | inet_ntop | `implemented` | Posix::inet_ntop | 1 | 0x13d78ca |
| `Xs9hdiD7sAA` | pthread_setschedparam | `implemented` | Posix::pthread_setschedparam | 1 | 0x1e6e727 |
| `dQHWEsJtoE4` | pthread_mutexattr_init | `implemented` | Posix::pthread_mutexattr_init | 1 | 0x15d8e03 |
| `mDmgMOGVUqg` | pthread_mutexattr_settype | `implemented` | Posix::pthread_mutexattr_settype | 1 | 0x15d8e15 |
| `oBr313PppNE` | sendto | `implemented` | Posix::sendto | 1 | 0x13f1490 |
| `pxnCmagrtao` | listen | `implemented` | Posix::listen | 1 | 0x13ee7af |
| `ttHNfU+qDBU` | pthread_mutex_init | `implemented` | Posix::pthread_mutex_init | 1 | 0x15d8e25 |
| `NN01qLRhiqU` |  | `missing` |  | 1 | 0x121385e |

### libScePsml

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `+2KpvixvL6E` |  | `implemented` | Psml::PsmlGetMainMemoryRequirements | 1 | 0x1e73a60 |
| `3WVD91e12ZQ` |  | `implemented` | Psml::PsmlInitialize | 1 | 0x1e73a50 |
| `AHalTX9wFZY` |  | `implemented` | Psml::PsmlGetWorkAreaSize | 1 | 0x1e73aeb |
| `FSGaTQze0UY` |  | `implemented` | Psml::PsmlValidateObject | 1 | 0x1e73bd0 |
| `GHna9-DvnUk` |  | `implemented` | Psml::PsmlGetProgress | 1 | 0x1e73ba0 |
| `GJY0MvuTcs8` |  | `implemented` | Psml::PsmlRequestCapture | 1 | 0x1e73bb0 |
| `JaLBe0P3jSU` |  | `implemented` | Psml::PsmlContextFinalize | 1 | 0x1e73ab0 |
| `LXq+6mIxpCw` |  | `implemented` | Psml::PsmlValidateObject | 1 | 0x1e73bc4 |
| `VGjrQa-WqdU` |  | `implemented` | Psml::PsmlGetContextMemoryRequirements | 1 | 0x1e73a90 |
| `eWoKNeB6V-k` |  | `implemented` | Psml::PsmlSharedResourcesInitialize | 1 | 0x1e73a70 |
| `jEevBXmagOQ` |  | `implemented` | Psml::PsmlSharedResourcesFinalize | 1 | 0x1e73a80 |
| `94iBp3KvIuI` |  | `missing` |  | 1 | 0x1e73b6a |
| `fccGInHrj8A` |  | `missing` |  | 1 | 0x1e73aa0 |

### libSceRtc

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `zO9UL3qIINQ` | sceRtcGetCurrentNetworkTick | `implemented` | Rtc::RtcGetCurrentNetworkTick | 5 | 0x652a37, 0x652c03, 0x680b81 |

### libSceSaveDataDialog.native

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `KK3Bdg1RWK0` | sceSaveDataDialogUpdateStatus | `implemented` | SaveDataDialog::SaveDataDialogUpdateStatus | 19 | 0x8983a3, 0x89912c, 0x89920f |
| `s9e3+YpRnzw` | sceSaveDataDialogInitialize | `implemented` | SaveDataDialog::SaveDataDialogInitialize | 12 | 0x898fe0, 0x8992b5, 0x8992da |
| `4tPhsP6FpDI` | sceSaveDataDialogOpen | `implemented` | SaveDataDialog::SaveDataDialogOpen | 11 | 0x899701, 0x899866, 0x8999dc |
| `yEiJ-qqr6Cg` | sceSaveDataDialogGetResult | `implemented` | SaveDataDialog::SaveDataDialogGetResult | 8 | 0x89915c, 0x899555, 0x8995db |
| `en7gNVnh878` | sceSaveDataDialogIsReadyToDisplay | `implemented` | SaveDataDialog::SaveDataDialogIsReadyToDisplay | 3 | 0x8983a8, 0x899a40, 0x89cc08 |
| `fH46Lag88XY` | sceSaveDataDialogClose | `implemented` | SaveDataDialog::SaveDataDialogClose | 3 | 0x89948d, 0x899788, 0x89c701 |
| `YuH2FA7azqQ` | sceSaveDataDialogTerminate | `implemented` | SaveDataDialog::SaveDataDialogTerminate | 2 | 0x89a927, 0x89e6a5 |
| `ERKzksauAJA` | sceSaveDataDialogGetStatus | `implemented` | SaveDataDialog::SaveDataDialogGetStatus | 1 | 0x89ef34 |
| `hay1CfTmLyA` | sceSaveDataDialogProgressBarSetValue | `stub` | SaveDataDialog::SaveDataDialogProgressBarSetValue (return_constant) | 12 | 0x899a54, 0x899ad0, 0x899bc4 |

### libSceSaveData_native

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `S1GkePI17zQ` | sceSaveDataDelete | `implemented` | ::Libs::SaveData::SaveDataDelete | 6 | 0x8991a4, 0x8991cd, 0x89cc4f |
| `uW4vfTwMQVo` | sceSaveDataUmount2 | `implemented` | ::Libs::SaveData::SaveDataUmount2 | 4 | 0x899365, 0x89938f, 0x89ce4c |
| `ZP4e7rlzOUk` | sceSaveDataMount3 | `implemented` | ::Libs::SaveData::SaveDataMount3 | 2 | 0x355c2, 0x5a349 |
| `gjRZNnw0JPE` | sceSaveDataCreateTransactionResource | `implemented` | ::Libs::SaveData::SaveDataCreateTransactionResource | 2 | 0x8982aa, 0x89b3aa |
| `65VH0Qaaz6s` | sceSaveDataGetMountInfo | `implemented` | ::Libs::SaveData::SaveDataGetMountInfo | 1 | 0x89af64 |
| `85zul--eGXs` | sceSaveDataSetParam | `implemented` | ::Libs::SaveData::SaveDataSetParam | 1 | 0x89d09d |
| `c88Yy54Mx0w` | sceSaveDataSaveIcon | `implemented` | ::Libs::SaveData::SaveDataSaveIcon | 1 | 0x89c912 |
| `dyIhnXq-0SM` | sceSaveDataDirNameSearch | `implemented` | ::Libs::SaveData::SaveDataDirNameSearch | 1 | 0x897bf0 |
| `ie7qhZ4X0Cc` | sceSaveDataCommit | `implemented` | ::Libs::SaveData::SaveDataCommit | 1 | 0x89cda2 |
| `sDCBrmc61XU` | sceSaveDataPrepare | `implemented` | ::Libs::SaveData::SaveDataPrepare | 1 | 0x89b027 |
| `yKDy8S5yLA0` | sceSaveDataTerminate | `implemented` | ::Libs::SaveData::SaveDataTerminate | 1 | 0x89eeb4 |
| `lJUQuaKqoKY` | sceSaveDataDeleteTransactionResource | `stub` | ::Libs::SaveData::SaveDataDeleteTransactionResource (return_constant) | 2 | 0x89a932, 0x89e6b0 |
| `TywrFKCoLGY` | sceSaveDataInitialize3 | `stub` | ::Libs::SaveData::SaveDataInitialize3 (return_constant) | 1 | 0x89ee4a |

### libSceShare

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `7QZtURYnXG4` | sceShareSetContentParam | `implemented` | Share::ShareSetContentParam | 1 | 0x884446 |
| `nBDD66kiFW8` | sceShareInitialize | `stub` | LibShare::ShareInitialize (return_constant) | 2 | 0x884369, 0x8843d3 |

### libSceSigninDialog

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `Bw31liTFT3A` | sceSigninDialogUpdateStatus | `implemented` | SigninDialog::SigninDialogUpdateStatus | 1 | 0x1403354 |
| `JlpJVoRWv7U` | sceSigninDialogOpen | `implemented` | SigninDialog::SigninDialogOpen | 1 | 0x1403612 |
| `mlYGfmqE3fQ` | sceSigninDialogInitialize | `implemented` | SigninDialog::SigninDialogInitialize | 1 | 0x1403585 |

### libSceSsl

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `hdpVEUDFW3s` | sceSslInit | `implemented` | Ssl::SslInit [só NID] | 4 | 0x8708dd, 0x88de4d, 0x13aed91 |
| `0K1yQ6Lv-Yc` | sceSslTerm | `implemented` | Ssl::SslTerm [só NID] | 3 | 0x870c73, 0x13af25c, 0x1d3d5ca |
| `DOwXL+FQMEY` |  | `missing` |  | 2 | 0x1d3ce04, 0x1d3ce3e |
| `viRXSHZYd0c` |  | `missing` |  | 1 | 0x88dff6 |

### libSceSysmodule

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `g8cM39EUZ6o` | sceSysmoduleLoadModule | `implemented` | Sysmodule::SysmoduleLoadModule | 32 | 0x63f449, 0x882b5e, 0x8842d7 |
| `eR2bZFAAU0Q` | sceSysmoduleUnloadModule | `implemented` | Sysmodule::SysmoduleUnloadModule | 5 | 0x63f46f, 0x88e049, 0x13af106 |

### libSceSystemGesture

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `FWF8zkhr854` | sceSystemGestureCreateTouchRecognizer | `implemented` | SystemGesture::SystemGestureCreateTouchRecognizer | 1 | 0xb92e1f |
| `GgFMb22sbbI` | sceSystemGestureUpdatePrimitiveTouchRecognizer | `implemented` | SystemGesture::SystemGestureUpdatePrimitiveTouchRecognizer | 1 | 0xb9360b |
| `TSKvgSz5ChU` | sceSystemGestureGetTouchEventByIndex | `implemented` | SystemGesture::SystemGestureGetTouchEventByIndex | 1 | 0xb93686 |
| `h8uongcBNVs` | sceSystemGestureGetTouchEventsCount | `implemented` | SystemGesture::SystemGestureGetTouchEventsCount | 1 | 0xb9362e |
| `j4h82CQWENo` | sceSystemGestureUpdateTouchRecognizer | `implemented` | SystemGesture::SystemGestureUpdateTouchRecognizer | 1 | 0xb93620 |
| `j4yXIA2jJ68` | sceSystemGestureClose | `implemented` | SystemGesture::SystemGestureClose | 1 | 0xb92e58 |
| `qpo-mEOwje0` | sceSystemGestureOpen | `implemented` | SystemGesture::SystemGestureOpen | 1 | 0xb92df7 |
| `3QYCmMlOlCY` | sceSystemGestureFinalizePrimitiveTouchRecognizer | `stub` | SystemGesture::SystemGestureFinalizePrimitiveTouchRecognizer (return_constant) | 1 | 0xb92567 |
| `3pcAvmwKCvM` | sceSystemGestureInitializePrimitiveTouchRecognizer | `stub` | SystemGesture::SystemGestureInitializePrimitiveTouchRecognizer (return_constant) | 1 | 0xb92345 |

### libSceSystemService

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `656LMQSrg6U` | sceSystemServiceReceiveEvent | `implemented` | SystemService::SystemServiceReceiveEvent | 2 | 0x88488a, 0x884dba |
| `Vo5V8KAwCmk` | sceSystemServiceHideSplashScreen | `implemented` | SystemService::SystemServiceHideSplashScreen | 2 | 0xbfa60a, 0xbfa61a |
| `rPo6tV8D9bM` | sceSystemServiceGetStatus | `implemented` | SystemService::SystemServiceGetStatus | 2 | 0x884858, 0x884d8d |
| `1n37q1Bvc5Y` | sceSystemServiceGetDisplaySafeAreaInfo | `implemented` | SystemService::SystemServiceGetDisplaySafeAreaInfo | 1 | 0x90a016 |
| `3RQ5aQfnstU` | sceSystemServiceGetNoticeScreenSkipFlag | `implemented` | SystemService::SystemServiceGetNoticeScreenSkipFlag | 1 | 0x7c6c03 |
| `JoBqSQt1yyA` | sceSystemServiceLoadExec | `implemented` | SystemService::SystemServiceLoadExec | 1 | 0x847302 |
| `fZo48un7LK4` | sceSystemServiceParamGetInt | `implemented` | SystemService::SystemServiceParamGetInt | 1 | 0x865991 |

### libSceUserService

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `CdWp0oHWGr0` | sceUserServiceGetInitialUser | `implemented` | UserService::UserServiceGetInitialUser | 26 | 0x3eff7, 0x63f4d4, 0x64feee |
| `yH17Q6NWtVg` | sceUserServiceGetEvent | `implemented` | UserService::UserServiceGetEvent | 2 | 0x8844f6, 0x884554 |
| `-sD02mFDBh4` | sceUserServiceGetGamePresets | `implemented` | UserService::UserServiceGetGamePresets | 1 | 0x7c91e9 |
| `1xxcMiGu2fo` | sceUserServiceGetUserName | `implemented` | UserService::UserServiceGetUserName | 1 | 0x909efa |
| `fPhymKNvK-A` | sceUserServiceGetLoginUserIdList | `implemented` | UserService::UserServiceGetLoginUserIdList | 1 | 0xb9236d |
| `j3YMu1MVNNo` | sceUserServiceInitialize | `stub` | UserService::UserServiceInitialize (return_constant) | 1 | 0x883d94 |

### libSceUserServicePlatformPrivacyWs1

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `D-CzAxQL0XI` |  | `stub` | UserService::UserServicePlatformPrivacyWs1Stub (name) [só NID] | 1 | 0x8f7dec |

### libSceVideoOut

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `CBiu4mCE1DA` | sceVideoOutSetFlipRate | `implemented` | VideoOut::VideoOutSetFlipRate | 5 | 0x90af45, 0x90b2de, 0x90b396 |
| `utPrVdxio-8` | sceVideoOutGetOutputStatus | `implemented` | VideoOut::VideoOutGetOutputStatus | 3 | 0x90acab, 0x90ad46, 0x90af53 |
| `zgXifHT9ErY` | sceVideoOutIsFlipPending | `implemented` | VideoOut::VideoOutIsFlipPending | 3 | 0x90a7e4, 0x90a806, 0x90aa16 |
| `DYhhWbJSeRg` |  | `implemented` | VideoOut::VideoOutColorSettingsSetGamma | 2 | 0x90af25, 0x90b34e |
| `HuViW4HnrOw` | sceVideoOutSubmitChangeBufferAttribute2 | `implemented` | VideoOut::VideoOutSubmitChangeBufferAttribute2 | 2 | 0x90a5f6, 0x90acfe |
| `N5KDtkIjjJ4` | sceVideoOutUnregisterBuffers | `implemented` | VideoOut::VideoOutUnregisterBuffers | 2 | 0x90aa2b, 0x90b501 |
| `PjS5uASwcV8` | sceVideoOutSetBufferAttribute2 | `implemented` | VideoOut::VideoOutSetBufferAttribute2 | 2 | 0x90a965, 0x1d1e753 |
| `U46NwOiJpys` | sceVideoOutSubmitFlip | `implemented` | VideoOut::VideoOutSubmitFlip | 2 | 0x90a764, 0x90a9fb |
| `j6RaAUlaLv0` | sceVideoOutWaitVblank | `implemented` | VideoOut::VideoOutWaitVblank | 2 | 0x90a815, 0x90aa06 |
| `pv9CI5VC+R0` |  | `implemented` | VideoOut::VideoOutAdjustColor | 2 | 0x90af38, 0x90b362 |
| `MTxxrOCeSig` | sceVideoOutSetWindowModeMargins | `implemented` | VideoOut::VideoOutSetWindowModeMargins | 1 | 0x90b487 |
| `Up36PTk687E` | sceVideoOutOpen | `implemented` | VideoOut::VideoOutOpen | 1 | 0x90ae8c |
| `rKBUtgRrtbk` | sceVideoOutRegisterBuffers2 | `implemented` | VideoOut::VideoOutRegisterBuffers2 | 1 | 0x90aad4 |
| `uquVH4-Du78` | sceVideoOutClose | `implemented` | VideoOut::VideoOutClose | 1 | 0x90b581 |

### libc

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `tsvEmnenz48` |  | `implemented` | LibC::cxa_atexit | 5737 | 0xd454, 0xd54c, 0xd62f |
| `hcuQgD53UxM` |  | `implemented` | LibC::libc_printf | 1131 | 0x21e4a9, 0x21f50f, 0x823964 |
| `wLlFkwG9UcQ` |  | `implemented` | LibC::libc_time | 51 | 0x65d051, 0x65eddd, 0x65edf8 |
| `YQ0navp+YIc` | puts | `implemented` | LibC::puts | 16 | 0x8e7090, 0x12c1237, 0x12c7e57 |
| `efhK-YSUYYQ` |  | `implemented` | LibC::libc_localtime | 14 | 0x83268b, 0xb1b828, 0xb1b8a9 |
| `Av3zjWi64Kw` |  | `implemented` | LibC::libc_strftime | 12 | 0xb1b846, 0xb1b8c7, 0xb1b944 |
| `8G2LB+A3rzg` | atexit | `implemented` | LibC::atexit | 4 | 0x8c, 0x98, 0x11a35d7 |
| `L1SBTkC+Cvw` | abort | `implemented` | LibC::abort | 4 | 0x7f2dee, 0x7f385e, 0x88e9bd |
| `n7AepwR0s34` |  | `implemented` | LibC::libc_mktime | 4 | 0x8325fa, 0x832672, 0x11dc478 |
| `-VVn74ZyhEs` |  | `implemented` | LibC::libc_difftime | 1 | 0x1213772 |
| `1mecP7RgI2A` |  | `implemented` | LibC::libc_gmtime | 1 | 0x121349d |
| `XKRegsFpEpk` | catchReturnFromMain | `implemented` | LibC::catchReturnFromMain | 1 | 0xb3 |
| `bzQExy189ZI` | _init_env | `implemented` | LibC::init_env | 1 | 0x84 |
| `uMei1W9uyNo` | exit | `implemented` | LibC::exit | 1 | 0xba |
| `P330P3dFF68` |  | `implemented` | &LibC::g_need_flag | 0 |  |
| `3GPpjQdAMTw` |  | `provided_by_game_module` | sce_module/libc.prx | 9444 | 0x35aec, 0x35baa, 0x35c61 |
| `9rAeANT2tyE` |  | `provided_by_game_module` | sce_module/libc.prx | 9442 | 0x35b8c, 0x35c4a, 0x35d01 |
| `lYDzBVE5mZs` |  | `provided_by_game_module` | sce_module/libc.prx | 6517 | 0x5cc, 0x3cac, 0xbb89 |
| `+P6FRGH4LfA` |  | `provided_by_game_module` | sce_module/libc.prx | 2704 | 0xf1fc, 0xfaf3, 0x1111a |
| `Q3VBxCXhUHs` |  | `provided_by_game_module` | sce_module/libc.prx | 1889 | 0xf28d, 0xfb9b, 0x111aa |
| `8zTFvBIAIN8` |  | `provided_by_game_module` | sce_module/libc.prx | 1564 | 0xe6c1, 0xead0, 0xeb48 |
| `lKEN2IebgJ0` |  | `provided_by_game_module` | sce_module/libc.prx | 1115 | 0x2646, 0x6ef90, 0xa1235 |
| `j4ViWNHEgww` |  | `provided_by_game_module` | sce_module/libc.prx | 1090 | 0x183c1, 0x1a0d1, 0x1afec |
| `EMutwaQ34Jo` |  | `provided_by_game_module` | sce_module/libc.prx | 776 | 0x89e018, 0x89e0a7, 0x15b7a75 |
| `AV6ipCNa4Rw` |  | `provided_by_game_module` | sce_module/libc.prx | 748 | 0x41ec4, 0x41f45, 0x41f98 |
| `WkkeywLJcgU` |  | `provided_by_game_module` | sce_module/libc.prx | 456 | 0x2918b, 0x76aaa, 0xeb346 |
| `1D0H2KNjshE` |  | `provided_by_game_module` | sce_module/libc.prx | 414 | 0xc5476, 0xc54df, 0xc555e |
| `pXvbDfchu6k` |  | `provided_by_game_module` | sce_module/libc.prx | 334 | 0x4a46, 0x4c67, 0xb2ba |
| `pNtJdE3x49E` |  | `provided_by_game_module` | sce_module/libc.prx | 317 | 0x2c9724, 0x2c973b, 0x2c9752 |
| `Q2V+iqvjgC0` |  | `provided_by_game_module` | sce_module/libc.prx | 303 | 0x11427, 0x1aad0, 0x37180 |
| `zlfEH8FmyUA` |  | `provided_by_game_module` | sce_module/libc.prx | 227 | 0xc970a, 0x17c29a, 0x19d380 |
| `QJ5xVfKkni0` |  | `provided_by_game_module` | sce_module/libc.prx | 221 | 0xbf1de, 0xbf704, 0xbf894 |
| `Ezzq78ZgHPs` |  | `provided_by_game_module` | sce_module/libc.prx | 215 | 0x2ca8e8, 0x2ca91b, 0x2ca987 |
| `d08RCvZNNR8` |  | `provided_by_game_module` | sce_module/libc.prx | 215 | 0x265b, 0xf361b, 0x11c61b |
| `Ovb2dSJOAuE` |  | `provided_by_game_module` | sce_module/libc.prx | 203 | 0x1489c, 0x148b7, 0x148ce |
| `SRI6S9B+-a4` |  | `provided_by_game_module` | sce_module/libc.prx | 131 | 0x816323, 0x8f44cf, 0x8f4577 |
| `E8wCoUEbfzk` |  | `provided_by_game_module` | sce_module/libc.prx | 128 | 0x6755db, 0x6dc0be, 0x6dc0e1 |
| `1uJgoVq3bQU` |  | `provided_by_game_module` | sce_module/libc.prx | 120 | 0x14b2e, 0x14b45, 0x2c40fa |
| `pztV4AF18iI` |  | `provided_by_game_module` | sce_module/libc.prx | 119 | 0x796d77, 0x8e7494, 0x8e7539 |
| `eLdDw6l0-bU` |  | `provided_by_game_module` | sce_module/libc.prx | 111 | 0xbd12a, 0xbd159, 0xbd1e0 |
| `88Vv-AzHVj8` |  | `provided_by_game_module` | sce_module/libc.prx | 88 | 0x853f, 0x855e, 0xaaa80 |
| `tcVi5SivF7Q` |  | `provided_by_game_module` | sce_module/libc.prx | 84 | 0x7cfe75, 0x7cff00, 0x7cff99 |
| `6sJWiWSRuqk` |  | `provided_by_game_module` | sce_module/libc.prx | 80 | 0x4d215, 0x4d29c, 0x4dda0 |
| `cpCOXWMgha0` |  | `provided_by_game_module` | sce_module/libc.prx | 71 | 0x33c3d3, 0xa51e42, 0xa5202e |
| `0nV21JjYCH8` |  | `provided_by_game_module` | sce_module/libc.prx | 66 | 0x4bc420, 0x4bc6dc, 0x4c3ffd |
| `DfivPArhucg` |  | `provided_by_game_module` | sce_module/libc.prx | 64 | 0x121e365, 0x121e401, 0x121e8f5 |
| `viiwFMaNamA` |  | `provided_by_game_module` | sce_module/libc.prx | 60 | 0x593f3, 0x5942e, 0x5945f |
| `8zsu04XNsZ4` |  | `provided_by_game_module` | sce_module/libc.prx | 59 | 0x2e3fa0, 0x2e4075, 0x2e410d |
| `kHg45qPC6f0` |  | `provided_by_game_module` | sce_module/libc.prx | 59 | 0x269f5, 0x26b84, 0x26f6e |
| `FM5NPnLqBc8` |  | `provided_by_game_module` | sce_module/libc.prx | 55 | 0x291a4, 0x76ac3, 0x1d72b3 |
| `Q4rRL34CEeE` |  | `provided_by_game_module` | sce_module/libc.prx | 47 | 0x86e9e9, 0x86e9fd, 0x8e7a71 |
| `ob5xAW4ln-0` |  | `provided_by_game_module` | sce_module/libc.prx | 40 | 0x65359b, 0x6535da, 0x7ec0e5 |
| `Al8MZJh-4hM` |  | `provided_by_game_module` | sce_module/libc.prx | 35 | 0x242f, 0x25f2, 0xa100e |
| `-P6FNMzk2Kc` |  | `provided_by_game_module` | sce_module/libc.prx | 34 | 0x8e81a8, 0x8e83be, 0x99eb54 |
| `5TjaJwkLWxE` |  | `provided_by_game_module` | sce_module/libc.prx | 34 | 0x27332, 0x273e8, 0x1ce75f |
| `3sssb+7Wn9M` |  | `provided_by_game_module` | sce_module/libc.prx | 33 | 0x200c4, 0x20140, 0x201b4 |
| `lhpd6Wk6ccs` |  | `provided_by_game_module` | sce_module/libc.prx | 33 | 0xc127b3, 0xc127ed, 0xc1280e |
| `aesyjrHVWy4` |  | `provided_by_game_module` | sce_module/libc.prx | 32 | 0x6db024, 0x8307b1, 0x8c92f1 |
| `H8ya2H00jbI` |  | `provided_by_game_module` | sce_module/libc.prx | 31 | 0x12152a3, 0x15d2000, 0x1e00bb0 |
| `kiZSXIWd9vg` |  | `provided_by_game_module` | sce_module/libc.prx | 31 | 0x8a8e3, 0x7f7ef0, 0x7f7f18 |
| `QI-x0SL8jhw` |  | `provided_by_game_module` | sce_module/libc.prx | 29 | 0x86e9da, 0x8e78f5, 0x8e7fe9 |
| `ZE6RNL+eLbk` |  | `provided_by_game_module` | sce_module/libc.prx | 29 | 0x188605, 0x189645, 0x196d88 |
| `EH-x713A99c` |  | `provided_by_game_module` | sce_module/libc.prx | 28 | 0x851b, 0xaaad0, 0x3ad14b |
| `tIhsqj0qsFE` |  | `provided_by_game_module` | sce_module/libc.prx | 28 | 0x66657d, 0x6665ae, 0x666715 |
| `g3ShSirD50I` |  | `provided_by_game_module` | sce_module/libc.prx | 27 | 0x106bf52, 0x106bf73, 0x106c103 |
| `Y7aJ1uydPMo` |  | `provided_by_game_module` | sce_module/libc.prx | 25 | 0x66694a, 0x6669ba, 0x666ab3 |
| `rQFVBXp-Cxg` |  | `provided_by_game_module` | sce_module/libc.prx | 25 | 0x7da468, 0x7da47f, 0x1213fc2 |
| `9yDWMxEFdJU` |  | `provided_by_game_module` | sce_module/libc.prx | 24 | 0x1613cb, 0x46dfbe, 0x46e263 |
| `gQX+4GDQjpM` |  | `provided_by_game_module` | sce_module/libc.prx | 24 | 0x667262, 0x66744d, 0x6675f2 |
| `HUbZmOnT-Dg` |  | `provided_by_game_module` | sce_module/libc.prx | 22 | 0x8f059f, 0x8f05b3, 0x8f07f6 |
| `sUP1hBaouOw` |  | `provided_by_game_module` | sce_module/libc.prx | 22 | 0x11aeee6, 0x11b1649, 0x1200250 |
| `2vDqwBlpF-o` |  | `provided_by_game_module` | sce_module/libc.prx | 21 | 0x7cf6a3, 0x7cf6c7, 0x7d7892 |
| `wuAQt-j+p4o` |  | `provided_by_game_module` | sce_module/libc.prx | 20 | 0x982213, 0x9cb665, 0x9db003 |
| `HFLNP4R4Elc` |  | `provided_by_game_module` | sce_module/libc.prx | 19 | 0x7cf34f, 0x7cf4af, 0x7d990b |
| `RQXLbdT2lc4` |  | `provided_by_game_module` | sce_module/libc.prx | 19 | 0x85f6e6, 0x907229, 0x994131 |
| `0WMHDb5Dt94` |  | `provided_by_game_module` | sce_module/libc.prx | 17 | 0xb83f11, 0xb83f74, 0xb83fc4 |
| `Zf7ewes1VtY` |  | `provided_by_game_module` | sce_module/libc.prx | 17 | 0x51603, 0x8891f, 0xef60a |
| `gNQ1V2vfXDE` |  | `provided_by_game_module` | sce_module/libc.prx | 16 | 0x13f00c, 0x21e19c, 0x320fdc |
| `jMB7EFyu30Y` |  | `provided_by_game_module` | sce_module/libc.prx | 16 | 0x8f05d8, 0x8f0650, 0x8f0827 |
| `xeYO4u7uyJ0` |  | `provided_by_game_module` | sce_module/libc.prx | 15 | 0x7da3e6, 0x7da7f8, 0x7db057 |
| `34nH7v2xvNQ` |  | `provided_by_game_module` | sce_module/libc.prx | 14 | 0x12200d5, 0x1220325, 0x1220565 |
| `5OqszGpy7Mg` |  | `provided_by_game_module` | sce_module/libc.prx | 13 | 0x3fb4aa, 0x6443d5, 0x644494 |
| `FOt55ZNaVJk` |  | `provided_by_game_module` | sce_module/libc.prx | 13 | 0x97d992, 0x97dc22, 0xa1a3f9 |
| `hsi9drzHR2k` |  | `provided_by_game_module` | sce_module/libc.prx | 13 | 0x91dd14, 0x91df90, 0x9e40b0 |
| `kALvdgEv5ME` |  | `provided_by_game_module` | sce_module/libc.prx | 13 | 0x673928, 0x673939, 0x6764d7 |
| `uodLYyUip20` |  | `provided_by_game_module` | sce_module/libc.prx | 13 | 0x7da40f, 0x7da67f, 0x7db098 |
| `Qazy8LmXTvw` |  | `provided_by_game_module` | sce_module/libc.prx | 12 | 0x7da470, 0x1214040, 0x143a935 |
| `RIa6GnWp+iU` |  | `provided_by_game_module` | sce_module/libc.prx | 12 | 0x1210989, 0x1213cd5, 0x1213d73 |
| `Ze2I81YNykw` |  | `provided_by_game_module` | sce_module/libc.prx | 12 | 0xafd231, 0xafdd87, 0xb0005f |
| `d3dMyWORw8A` |  | `provided_by_game_module` | sce_module/libc.prx | 12 | 0x3277, 0x4bc431, 0x4bc6ed |
| `fnUEjBCNRVU` |  | `provided_by_game_module` | sce_module/libc.prx | 12 | 0x2d9328, 0x2d94da, 0x2d9aa8 |
| `9LCjpWyQ5Zc` |  | `provided_by_game_module` | sce_module/libc.prx | 11 | 0x867743, 0x867b85, 0x867f74 |
| `9nf8joUTSaQ` |  | `provided_by_game_module` | sce_module/libc.prx | 11 | 0x67396b, 0x673972, 0x6764f8 |
| `MpxhMh8QFro` |  | `provided_by_game_module` | sce_module/libc.prx | 11 | 0x7cf18f, 0x89c797, 0x89c7ee |
| `weDug8QD-lE` |  | `provided_by_game_module` | sce_module/libc.prx | 11 | 0x1bb57f, 0x1bb5b0, 0x995778 |
| `8u8lPzUEq+U` |  | `provided_by_game_module` | sce_module/libc.prx | 10 | 0x121662c, 0x15ba29c, 0x15ba449 |
| `DbEnA+MnVIw` |  | `provided_by_game_module` | sce_module/libc.prx | 10 | 0xbcb5b, 0xbcbda, 0xbcc9b |
| `a2d1iefnHTk` |  | `provided_by_game_module` | sce_module/libc.prx | 10 | 0x677620, 0x677639, 0x7f1ed0 |
| `nwujzxOPXzQ` |  | `provided_by_game_module` | sce_module/libc.prx | 10 | 0x1cf327, 0x1d1381, 0x719ef3 |
| `2WE3BTYVwKM` |  | `provided_by_game_module` | sce_module/libc.prx | 8 | 0x12152d3, 0x15d2010, 0x1e2afa0 |
| `fiiNDnNBKVY` |  | `provided_by_game_module` | sce_module/libc.prx | 8 | 0x8324ba, 0x832552, 0x8325f2 |
| `q0F6yS-rCms` |  | `provided_by_game_module` | sce_module/libc.prx | 8 | 0x819294, 0x819314, 0x825494 |
| `GZWjF-YIFFk` |  | `provided_by_game_module` | sce_module/libc.prx | 7 | 0xaaa5a, 0x31fdac, 0x8ece55 |
| `Ls4tzzhimqQ` |  | `provided_by_game_module` | sce_module/libc.prx | 7 | 0x82db01, 0x82dcb3, 0x9999f7 |
| `bRPUrNROyOI` |  | `provided_by_game_module` | sce_module/libc.prx | 7 | 0xa124b, 0xf04fb, 0x15b5cb |
| `lbB+UlZqVG0` |  | `provided_by_game_module` | sce_module/libc.prx | 7 | 0x7da4b0, 0x899b3e, 0x899c66 |
| `q+9E0X3aWpU` |  | `provided_by_game_module` | sce_module/libc.prx | 6 | 0x8327d2, 0x13b13f4, 0x13b541a |
| `rcQCUr0EaRU` |  | `provided_by_game_module` | sce_module/libc.prx | 6 | 0x321a, 0x16b7ed, 0x11af267 |
| `xEszJVGpybs` |  | `provided_by_game_module` | sce_module/libc.prx | 6 | 0xc0e075, 0xc0e142, 0xc1276d |
| `5bBacGLyLOs` |  | `provided_by_game_module` | sce_module/libc.prx | 5 | 0x8324c1, 0x832559, 0x11dc2cd |
| `6pa-Aa4kTHk` |  | `provided_by_game_module` | sce_module/libc.prx | 5 | 0x676db2, 0x676deb, 0x676ec6 |
| `MUjC4lbHrK4` |  | `provided_by_game_module` | sce_module/libc.prx | 5 | 0x1213d5b, 0x1213dd5, 0x1214c77 |
| `CjQROLB88a4` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x18e905, 0x18e94a, 0x18e9ff |
| `K+YIrBadUlc` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x67394f, 0x7f2e8f, 0x7f38ff |
| `NesIgTmfF0Q` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x8b692d, 0xa8a9a6, 0xa8aa91 |
| `Ujf3KzMvRmI` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x801eb5, 0x11170ad, 0x111715d |
| `WDpobjImAb4` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x106b4a3, 0x106be34, 0x106cb53 |
| `gjbmYpP-XJQ` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x120cfc7, 0x120d11c, 0x120e9ef |
| `m5wN+SwZOR4` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x823b20, 0x11a9fa9, 0x11aa1a9 |
| `olQf-vTaj2Q` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x676cd5, 0x676fa3, 0x7f3bff |
| `taOj6NIm7DM` |  | `provided_by_game_module` | sce_module/libc.prx | 4 | 0x673960, 0x7f2eb8, 0x7f3934 |
| `-QgqOT5u2Vk` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x1d3f05f, 0x1d3f1d4, 0x1d40410 |
| `1Pk0qZQGeWo` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x84381f, 0x16579de, 0x16579f9 |
| `AHxyhN96dy4` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x7db08b, 0x7db15b, 0x1dbfe21 |
| `GMpvxPFW924` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x11a9f9f, 0x11aa19f, 0x11aa34c |
| `HHXmPak83kQ` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x673958, 0x7f3928, 0x846e4a |
| `KdP-nULpuGw` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x12130a5, 0x1213120, 0x1214756 |
| `QZP6I9ZZxpE` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x1213409, 0x16aa32b, 0x16aa6b0 |
| `QrZZdJ8XsX0` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x8470d7, 0x12113ca, 0x1211452 |
| `aZK8lNei-Qw` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x1211447, 0x1211482, 0x143aef1 |
| `lA94ZgT+vMM` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x1d42dde, 0x1d5bb74, 0x1d5bc23 |
| `pKwslsMUmSk` |  | `provided_by_game_module` | sce_module/libc.prx | 3 | 0x7e0480, 0xb48b16, 0x121548e |
| `-kU6bB4M-+k` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x819283, 0x825483 |
| `3+UPM-9E6xY` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x169091f, 0x1e45e70 |
| `7-a7sBHeUQ8` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x11bb44b, 0x12219a0 |
| `77z+OH5zp5I` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2ffe, 0x7f3036 |
| `7Ly52zaL44Q` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1215333, 0x15d2062 |
| `7SXNu+0KBYQ` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x11bb28b, 0x1221760 |
| `EvS9U4rxAQk` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x677609, 0x7f22b3 |
| `EvYwPckXJyE` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f3b08, 0x7f3b36 |
| `GfxAp9Xyiqs` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x11af027, 0x11b17a8 |
| `H4MCONF+Gps` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1cc721, 0x1ccc77 |
| `JBcgYuW8lPU` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1215363, 0x15d2032 |
| `Mt6co-yzyjg` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x6738b2, 0x846db0 |
| `NVadfnzQhHQ` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1215733, 0x15d21a0 |
| `O4L+0oCN9zA` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1145428, 0x1e0132f |
| `Rlnw-UcmA5k` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2e6c, 0x7f38dc |
| `SAd0Z3wKwLA` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1145440, 0x15d2170 |
| `T7uyNqP7vQA` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1215303, 0x15d2100 |
| `WuMbPBKN1TU` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1215703, 0x15d20c0 |
| `YNzNkJzYqEg` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0xc099c1, 0xc0a9bc |
| `aFxknk3hTog` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2dac, 0x7f381c |
| `fffwELXNVFA` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x1210b71, 0x12149b3 |
| `gntpWkgb4sQ` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2f8e, 0x7f2fc6 |
| `gwAf8VMkXS0` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2ea5, 0x7f3915 |
| `kn0yiYeExgA` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x11454b0, 0x1d16842 |
| `pU-MxoFcxZc` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f3b68, 0x7f3b96 |
| `rtV7-jWC6Yg` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x12156d3, 0x15d20a0 |
| `x9uumWcxhXU` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x106ba4d, 0x106d11d |
| `xE51MX+B2G4` |  | `provided_by_game_module` | sce_module/libc.prx | 2 | 0x7f2d73, 0x7f37e3 |
| `+qitMEbkSWk` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x9814d8 |
| `-7nRJFXMxnM` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1131258 |
| `-LFO7jhD5CE` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x12145f0 |
| `1QJWxoB6pCo` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1131230 |
| `1cKlQv7Kvmg` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x108e9b |
| `24m4Z4bUaoY` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x176e3ba |
| `2X5agFjKxMc` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1d3ec46 |
| `4ITMYcbipA0` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x7f1f70 |
| `7KPYZ-jSAto` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x676507 |
| `8Q60JLJ6Rv4` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x12145e0 |
| `JM4EBvWT9rc` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x15d2180 |
| `JrwFIMzKNr0` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x121554e |
| `LfjFksmiu4Y` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0xb0035a |
| `LxcEU+ICu8U` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1dbfde0 |
| `MZO7FXyAPU8` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x121380c |
| `OXmauLdQ8kY` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1215393 |
| `PdnFCFqKGqA` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1145438 |
| `PtsB1Q9wsFA` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1213916 |
| `RqeErO3cFHU` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x80a55b |
| `St9nbxSoezk` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1dbfe2c |
| `VOBg+iNwB-4` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x15bbbb4 |
| `VPbJwTCgME0` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1215902 |
| `aaDMGGkXFxo` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x11454c0 |
| `jbz9I9vkqkk` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x15bba20 |
| `kA-TdiOCsaY` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x12154da |
| `kDZvoVssCgQ` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1216675 |
| `npLpPTaSuHg` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1214632 |
| `okSBuQ1sJdQ` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x6774fb |
| `rDMyAf1Jhug` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x1d5bb86 |
| `u0XOsuOmOzc` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x112e489 |
| `wZi5ly2guNw` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x7459ee |
| `xENtRue8dpI` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x98db9a |
| `ynwqogpIbL0` |  | `provided_by_game_module` | sce_module/libc.prx | 1 | 0x6764b8 |
| `+ROCBP8cIyY` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `1TDo-ImqkJc` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `2sWzhYqFH4E` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `3PxvyV7qPPQ` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `7ipah7h7Wjk` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `9ByRMdo7ywg` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `9Qe7XFSQ4Lk` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `EIyErVBW9QI` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `H8AprKeZtNg` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `Jk7KrKMQzDw` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `Mcrl2crhxu0` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `MmytiDdoGBA` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `OVV3+UimpiY` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `RhFDPGxQ4sA` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `T1cG+xkSd-g` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `Z+vcX3rnECg` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `b61-ZHIQuns` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `byV+FWlAnB4` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `pZ9WXcClPO8` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `tyHd3P7oDrU` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |
| `zr094EQ39Ww` |  | `provided_by_game_module` | sce_module/libc.prx | 0 |  |

### libkernel

| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |
|---|---|---|---|---:|---|
| `Ou3iL1abvng` |  | `implemented` | LibKernel::stack_chk_fail | 21289 | 0x113a, 0x137c, 0x192a |
| `9BcDykPmo1I` |  | `implemented` | LibKernel::get_error_addr | 41 | 0x876804, 0x876af1, 0x876d61 |
| `tn3VlD0hG60` | scePthreadMutexUnlock | `implemented` | LibKernel::PthreadMutexUnlock | 40 | 0x84124c, 0x111946c, 0x1119538 |
| `9UK1vLZQft4` | scePthreadMutexLock | `implemented` | LibKernel::PthreadMutexLock | 34 | 0x84115e, 0x11193c5, 0x11194c8 |
| `2Of0f+3mhhE` | scePthreadMutexDestroy | `implemented` | LibKernel::PthreadMutexDestroy | 29 | 0x841130, 0x1119064, 0x11190eb |
| `-2IRUCO--PM` | sceKernelReadTsc | `implemented` | LibKernel::KernelReadTsc | 24 | 0x1d3c543, 0x1d3c570, 0x1d3c5e8 |
| `1jfXLRVzisc` | sceKernelUsleep | `implemented` | LibKernel::KernelUsleep | 18 | 0x8416c6, 0x8416d6, 0x8416e0 |
| `1j3S3n-tTW4` | sceKernelGetTscFrequency | `implemented` | LibKernel::KernelGetTscFrequency | 17 | 0x831a14, 0x831a63, 0x831d96 |
| `cmo1RIYva9o` | scePthreadMutexInit | `implemented` | LibKernel::PthreadMutexInit | 16 | 0x8410fb, 0x111920f, 0x1119946 |
| `UK2Tl2DWUns` | sceKernelClose | `implemented` | FileSystem::KernelClose | 14 | 0x830386, 0x83058c, 0x16721ea |
| `aI+OeCz8xrQ` | scePthreadSelf | `implemented` | LibKernel::PthreadSelf | 14 | 0xbfa694, 0x111a290, 0x13afbc5 |
| `onNY9Byn-W8` | scePthreadJoin | `implemented` | LibKernel::PthreadJoin | 14 | 0x841ba5, 0x1124018, 0x15d8fa4 |
| `smWEktiyyG0` | scePthreadMutexattrDestroy | `implemented` | LibKernel::PthreadMutexattrDestroy | 14 | 0x841103, 0x1119951, 0x1d3c340 |
| `F8bUHwAG284` | scePthreadMutexattrInit | `implemented` | LibKernel::PthreadMutexattrInit | 12 | 0x8410dc, 0x111992b, 0x1d3c30c |
| `iMp8QpE+XO4` | scePthreadMutexattrSettype | `implemented` | LibKernel::PthreadMutexattrSettype | 12 | 0x8410e9, 0x1119938, 0x1d3c333 |
| `62KCwEMmzcM` | scePthreadAttrDestroy | `implemented` | LibKernel::PthreadAttrDestroy | 11 | 0x841a2b, 0x1123e91, 0x15d9172 |
| `4czppHBiriw` | sceKernelSignalSema | `implemented` | Semaphore::KernelSignalSema | 10 | 0x1143868, 0x11438b5, 0x119fc78 |
| `1G3lF1Gg1k8` | sceKernelOpen | `implemented` | FileSystem::KernelOpen | 9 | 0x83006a, 0x8300c3, 0x830210 |
| `6UgtwV+0zb4` | scePthreadCreate | `implemented` | LibKernel::PthreadCreate | 9 | 0x841a23, 0x1123e86, 0x15d9168 |
| `W0Hpm2X0uPE` | scePthreadSetprio | `implemented` | LibKernel::PthreadSetprio | 9 | 0x841a37, 0x841be4, 0x1123fd3 |
| `bt3CTBKmGyI` | scePthreadSetaffinity | `implemented` | LibKernel::PthreadSetaffinity | 9 | 0x841c37, 0xbfa6a1, 0x15d9014 |
| `nsYoNRywwNg` | scePthreadAttrInit | `implemented` | LibKernel::PthreadAttrInit | 9 | 0x84198d, 0x1123c95, 0x15d90d4 |
| `rVjRvHJ0X6c` | sceKernelVirtualQuery | `implemented` | Memory::KernelVirtualQuery | 9 | 0x80ec6a, 0x81090d, 0x8109cc |
| `R1Jvn8bSCW8` | sceKernelDeleteSema | `implemented` | Semaphore::KernelDeleteSema | 8 | 0x11436ad, 0x114370a, 0x114376d |
| `UTXzJbWhhTE` | scePthreadAttrSetstacksize | `implemented` | LibKernel::PthreadAttrSetstacksize | 8 | 0x8419bb, 0x1123d88, 0x15d914f |
| `eV9wAD2riIA` | sceKernelStat | `implemented` | FileSystem::KernelStat | 8 | 0x8300a7, 0x830542, 0x830bf1 |
| `oib76F-12fk` | sceKernelLseek | `implemented` | FileSystem::KernelLseek | 8 | 0x8305cc, 0x1672653, 0x167268f |
| `g+PZd2hiacg` | scePthreadCondDestroy | `implemented` | LibKernel::PthreadCondDestroy | 7 | 0x111904d, 0x11190cb, 0x1119160 |
| `+L98PIbGttk` | scePthreadRwlockUnlock | `implemented` | LibKernel::PthreadRwlockUnlock | 5 | 0x111a001, 0x111a081, 0x111a231 |
| `12wOHk8ywb0` | sceKernelPollSema | `implemented` | Semaphore::KernelPollSema | 5 | 0x11439c8, 0x1143a15, 0x119fbd8 |
| `2Tb92quprl0` | scePthreadCondInit | `implemented` | LibKernel::PthreadCondInit | 5 | 0x1119255, 0x1d3c3cd, 0x1dd714f |
| `3kg7rT0NQIs` | scePthreadExit | `implemented` | LibKernel::PthreadExit | 5 | 0x111a2d6, 0x1d3c254, 0x1dc0137 |
| `3qxgM4ezETA` | scePthreadAttrSetaffinity | `implemented` | LibKernel::PthreadAttrSetaffinity | 5 | 0x8419ed, 0x1123dff, 0x15d90e6 |
| `BmMjYxmew1w` | scePthreadCondTimedwait | `implemented` | LibKernel::PthreadCondTimedwait | 5 | 0x111963a, 0x1d3c42a, 0x1dd6feb |
| `Cg4srZ6TKbU` | sceKernelRead | `implemented` | FileSystem::KernelRead | 5 | 0x8305fc, 0x16725f9, 0x1672630 |
| `Xjoosiw+XPI` | sceKernelUuidCreate | `implemented` | LibKernel::KernelUuidCreate | 5 | 0x67f36a, 0x67f64d, 0x680c45 |
| `Zxa0VhQVTsk` | sceKernelWaitSema | `implemented` | Semaphore::KernelWaitSema | 5 | 0x114394e, 0x119fb3e, 0x1681e8a |
| `kDh-NfxgMtE` | scePthreadCondSignal | `implemented` | LibKernel::PthreadCondSignal | 5 | 0x1119441, 0x1d3c3f4, 0x1dd6f88 |
| `pO96TwzOm5E` | sceKernelGetDirectMemorySize | `implemented` | Memory::KernelGetDirectMemorySize | 5 | 0x80c22c, 0x80c296, 0x80c315 |
| `rTXw65xmLIA` | sceKernelAllocateDirectMemory | `implemented` | Memory::KernelAllocateDirectMemory | 5 | 0x80c339, 0x80cbf0, 0x80cdd3 |
| `-Wreprtu0Qs` | scePthreadAttrSetdetachstate | `implemented` | LibKernel::PthreadAttrSetdetachstate | 4 | 0x84199d, 0x1123d15, 0x15d90f4 |
| `188x57JYp0g` | sceKernelCreateSema | `implemented` | Semaphore::KernelCreateSema | 4 | 0x11437f3, 0x119fa41, 0x1681e64 |
| `7oxv3PPCumo` | sceKernelReserveVirtualRange | `implemented` | Memory::KernelReserveVirtualRange | 4 | 0x80d392, 0x80db4e, 0x80dbc2 |
| `BB+kb08Tl9A` | scePthreadRwlockDestroy | `implemented` | LibKernel::PthreadRwlockDestroy | 4 | 0x1119bcd, 0x1119c2a, 0x1119c8d |
| `L-Q3LEjIbgA` | sceKernelMapDirectMemory | `implemented` | Memory::KernelMapDirectMemory | 4 | 0x80c3f0, 0x80cca2, 0x1de3091 |
| `MBuItvba6z8` | sceKernelReleaseDirectMemory | `implemented` | Memory::KernelReleaseDirectMemory | 4 | 0xa52e4a, 0xa52e5f, 0x1de31c0 |
| `T72hz6ffq08` | scePthreadYield | `implemented` | LibKernel::PthreadYield | 4 | 0x841bd0, 0x111a2a0, 0x1d3c2c0 |
| `WKAXJ4XBPQ4` | scePthreadCondWait | `implemented` | LibKernel::PthreadCondWait | 4 | 0x1119685, 0x1d3c414, 0x1e6eb27 |
| `4+h9EzwKF4I` | scePthreadAttrSetschedpolicy | `implemented` | LibKernel::PthreadAttrSetschedpolicy | 3 | 0x8419d2, 0x15d9137, 0x1d3c1be |
| `DzES9hQF4f4` | scePthreadAttrSetschedparam | `implemented` | LibKernel::PthreadAttrSetschedparam | 3 | 0x8419e2, 0x15d912a, 0x1ddd572 |
| `JGgj7Uvrl+A` | scePthreadCondBroadcast | `implemented` | LibKernel::PthreadCondBroadcast | 3 | 0x1d3c404, 0x1e6e8c2, 0x1e6ee32 |
| `LJDwdSNTnDg` | sceKernelDeleteUserEvent | `implemented` | EventQueue::KernelDeleteUserEvent | 3 | 0x860939, 0x860979, 0x860dd7 |
| `eXbUSpEaTsA` | scePthreadAttrSetinheritsched | `implemented` | LibKernel::PthreadAttrSetinheritsched | 3 | 0x8419c5, 0x15d90fe, 0x1ddd55b |
| `fgxnMeTNUtY` | sceKernelGetProcessTimeCounter | `implemented` | LibKernel::KernelGetProcessTimeCounter | 3 | 0x11a9d79, 0x11a9dd0, 0x11a9de9 |
| `upoVrzMHFeE` | scePthreadMutexTrylock | `implemented` | LibKernel::PthreadMutexTrylock | 3 | 0x841209, 0x1119ab8, 0x1dc024f |
| `1-LFLmRFxxM` | sceKernelMkdir | `implemented` | FileSystem::KernelMkdir | 2 | 0x83190f, 0x1671e3c |
| `1tKyG7RlMJo` | scePthreadGetprio | `implemented` | LibKernel::PthreadGetprio | 2 | 0x1d3c290, 0x1e4b5da |
| `4R6-OvI2cEA` | sceKernelAddUserEvent | `implemented` | EventQueue::KernelAddUserEvent | 2 | 0x860a45, 0x861662 |
| `4wSze92BhLI` | sceKernelWrite | `implemented` | FileSystem::KernelWrite | 2 | 0x83064c, 0x1672844 |
| `5TgME6AYty4` | sceKernelAioDeleteRequest | `implemented` | KernelAioDeleteRequest | 2 | 0x1dd6ba0, 0x1dd6c42 |
| `6ULAa0fq4jA` | scePthreadRwlockInit | `implemented` | LibKernel::PthreadRwlockInit | 2 | 0x1119d15, 0x1d3c469 |
| `B+vc2AO2Zrc` | sceKernelAllocateMainDirectMemory | `implemented` | Memory::KernelAllocateMainDirectMemory | 2 | 0xa5249b, 0xa529f7 |
| `How7B8Oet6k` | scePthreadGetname | `implemented` | LibKernel::PthreadGetname | 2 | 0x13afd5f, 0x13b0016 |
| `IafI2PxcPnQ` | scePthreadMutexTimedlock | `implemented` | LibKernel::PthreadMutexTimedlock | 2 | 0x1119a2d, 0x1dd6f50 |
| `JTvBflhYazQ` | sceKernelWaitEventFlag | `implemented` | EventFlag::KernelWaitEventFlag | 2 | 0x841640, 0x841696 |
| `Ox9i0c7L5w0` | scePthreadRwlockRdlock | `implemented` | LibKernel::PthreadRwlockRdlock | 2 | 0x111a118, 0x1d3c480 |
| `aNz11fnnzi4` | sceKernelAvailableFlexibleMemorySize | `implemented` | Memory::KernelAvailableFlexibleMemorySize | 2 | 0x80d2a4, 0x80fd8b |
| `bIHoZCTomsI` | scePthreadRwlockTrywrlock | `implemented` | LibKernel::PthreadRwlockTrywrlock | 2 | 0x1119e81, 0x1119f41 |
| `cQke9UuBQOk` | sceKernelMunmap | `implemented` | Memory::KernelMunmap | 2 | 0x1de31b1, 0x1de4dd7 |
| `ejekcaNQNq0` | sceKernelGettimeofday | `implemented` | LibKernel::KernelGettimeofday | 2 | 0x11dc4e9, 0x1e53a9b |
| `fTx66l5iWIA` | sceKernelFsync | `implemented` | FileSystem::KernelFsync | 2 | 0x830687, 0x1672907 |
| `kBwCPsYX-m4` | sceKernelFstat | `implemented` | FileSystem::KernelFstat | 2 | 0x8306cb, 0x830724 |
| `mJ7aghmgvfc` | sceKernelGetEventId | `implemented` | EventQueue::KernelGetEventId | 2 | 0x860d28, 0x860d80 |
| `mqdNorrB+gI` | scePthreadRwlockWrlock | `implemented` | LibKernel::PthreadRwlockWrlock | 2 | 0x1119e21, 0x1d3c490 |
| `rcrVFJsQWRY` | scePthreadGetaffinity | `implemented` | LibKernel::PthreadGetaffinity | 2 | 0x841c0f, 0x1e6e639 |
| `vSMAm3cxYTY` | sceKernelMprotect | `implemented` | Memory::KernelMprotect | 2 | 0x1d095cc, 0x1d095f4 |
| `+r3rMFwItV4` | sceKernelPread | `implemented` | FileSystem::KernelPread | 1 | 0x830620 |
| `14bOACANTBo` |  | `implemented` | Posix::pthread_once | 1 | 0x97e5b4 |
| `23CPPI1tyBY` | sceKernelGetEventFilter | `implemented` | EventQueue::KernelGetEventFilter | 1 | 0x860ca4 |
| `2SKEx6bSq-4` | sceKernelBatchMap | `implemented` | Memory::KernelBatchMap | 1 | 0x80f355 |
| `2pOuoWoCxdk` | sceKernelAioPollRequest | `implemented` | KernelAioPollRequest | 1 | 0x1dd6b82 |
| `3PtV6p3QNX4` | scePthreadEqual | `implemented` | LibKernel::PthreadEqual | 1 | 0x13afcc8 |
| `4J2sUJmuHZQ` | sceKernelGetProcessTime | `implemented` | LibKernel::KernelGetProcessTime | 1 | 0x1dd7250 |
| `4oXYe9Xmk0Q` | sceKernelGetGPI | `implemented` | LibKernel::KernelGetGPI | 1 | 0x8469e7 |
| `4qGrR6eoP9Y` | scePthreadDetach | `implemented` | LibKernel::PthreadDetach | 1 | 0x1123f9c |
| `7uhBFWRAS60` | sceKernelClearEventFlag | `implemented` | EventFlag::KernelClearEventFlag | 1 | 0x841553 |
| `8mql9OcQnd4` | sceKernelDeleteEventFlag | `implemented` | EventFlag::KernelDeleteEventFlag | 1 | 0x8413dc |
| `9lvj5DjHZiA` | sceKernelPollEventFlag | `implemented` | EventFlag::KernelPollEventFlag | 1 | 0x84160d |
| `ASoW5WE-UPo` |  | `implemented` | Apr::SubmitCommandBufferAndGetResult | 1 | 0x1d356e4 |
| `AUXVxWeJU-A` | sceKernelUnlink | `implemented` | FileSystem::KernelUnlink | 1 | 0x1671ddc |
| `ApkYaHb8Sek` |  | `implemented` | Apr::GetFileStat | 1 | 0x1d35654 |
| `BNowx2l588E` | sceKernelGetProcessTimeCounterFrequency | `implemented` | LibKernel::KernelGetProcessTimeCounterFrequency | 1 | 0x11a9da3 |
| `BohYr-F7-is` | sceKernelSetPrtAperture | `implemented` | Memory::KernelSetPrtAperture | 1 | 0x80d05a |
| `BpFoboUJoZU` | sceKernelCreateEventFlag | `implemented` | EventFlag::KernelCreateEventFlag | 1 | 0x841317 |
| `C+Khtbbx2g8` |  | `implemented` | Apr::ResolveFilepathsWithPrefixToIdsAndFileSizesForEach | 1 | 0x1d355fb |
| `C0f7TJcbfac` | sceKernelAvailableDirectMemorySize | `implemented` | Memory::KernelAvailableDirectMemorySize | 1 | 0x80c2b3 |
| `D0OdFMjp46I` | sceKernelCreateEqueue | `implemented` | EventQueue::KernelCreateEqueue | 1 | 0x870a56 |
| `EI-5-jlq2dE` | scePthreadGetthreadid | `implemented` | LibKernel::PthreadGetthreadid | 1 | 0x1dc0040 |
| `HgX7+AORI58` | sceKernelAioSubmitReadCommands | `implemented` | KernelAioSubmitReadCommands | 1 | 0x1dd6b0a |
| `IOnSvHzqu6A` | sceKernelSetEventFlag | `implemented` | EventFlag::KernelSetEventFlag | 1 | 0x841491 |
| `IWIBBdTHit4` | sceKernelMapFlexibleMemory | `implemented` | Memory::KernelMapFlexibleMemory | 1 | 0x80d3b8 |
| `NH6xARDOVv8` | sceKernelGetOperationMode | `implemented` | LibKernel::KernelGetOperationMode | 1 | 0x84696d |
| `QzB4O+bJQyA` |  | `implemented` | Apr::ResolveFilepathsToIdsAndFileSizesForEach | 1 | 0x1d35589 |
| `Ru36fiTtJzA` | scePthreadAttrGetstackaddr | `implemented` | LibKernel::PthreadAttrGetstackaddr | 1 | 0x1dc0093 |
| `VB-BtuIW8Xc` |  | `implemented` | Apr::ResolveFilepathsWithPrefixToIdsForEach | 1 | 0x1d355b9 |
| `VW3TVZiM4-E` | sceKernelFtruncate | `implemented` | FileSystem::KernelFtruncate | 1 | 0x83066d |
| `WT-5NKy42fw` |  | `implemented` | Apr::ResolveFilepathsToIds | 1 | 0x1d35484 |
| `WvEu7yl3Ivg` |  | `implemented` | Apr::GetFileSize | 1 | 0x1d35624 |
| `XD3mDeybCnk` | scePthreadRwlockTryrdlock | `implemented` | LibKernel::PthreadRwlockTryrdlock | 1 | 0x111a1a1 |
| `adh--6nIqTk` | scePthreadRwlockTimedwrlock | `implemented` | LibKernel::PthreadRwlockTimedwrlock | 1 | 0x1119dbd |
| `eE4Szl8sil8` |  | `implemented` | Apr::SubmitCommandBuffer | 1 | 0x1d35684 |
| `eYAh2vlCY-U` |  | `implemented` | Apr::ResolveFilepathsToIdsForEach | 1 | 0x1d35554 |
| `fzyMKs9kim0` | sceKernelWaitEqueue | `implemented` | EventQueue::KernelWaitEqueue | 1 | 0x870e6b |
| `gEpBkcwxUjw` |  | `implemented` | Apr::ResolveFilepathsToIdsAndFileSizes | 1 | 0x1d354b9 |
| `i3HWvW35jao` |  | `implemented` | Apr::ResolveFilepathsWithPrefixToIds | 1 | 0x1d354e9 |
| `iPtZRWICjrM` | scePthreadRwlockTimedrdlock | `implemented` | LibKernel::PthreadRwlockTimedrdlock | 1 | 0x111a10d |
| `j2AIqSqJP0w` | sceKernelGetdents | `implemented` | FileSystem::KernelGetdents | 1 | 0x16720a5 |
| `jpFjmgAC5AE` | sceKernelDeleteEqueue | `implemented` | EventQueue::KernelDeleteEqueue | 1 | 0x870b21 |
| `m5-2bsNfv7s` | scePthreadCondattrInit | `implemented` | LibKernel::PthreadCondattrInit | 1 | 0x1dd7141 |
| `naInUjYt3so` | sceKernelRmdir | `implemented` | FileSystem::KernelRmdir | 1 | 0x1671ded |
| `qvMUCyyaCSI` |  | `implemented` | Apr::SubmitCommandBufferAndGetId | 1 | 0x1d356b4 |
| `rqwFKI4PAiM` |  | `implemented` | Apr::WaitCommandBuffer | 1 | 0x1d35714 |
| `tU5e3f9gSiU` | sceKernelIsTrinityMode | `implemented` | LibKernel::KernelIsTrinityMode | 1 | 0x846934 |
| `w5fcCG+t31g` |  | `implemented` | Apr::ResolveFilepathsWithPrefixToIdsAndFileSizes | 1 | 0x1d3552b |
| `waPcxYiR3WA` | scePthreadCondattrDestroy | `implemented` | LibKernel::PthreadCondattrDestroy | 1 | 0x1dd715a |
| `x1X76arYMxU` | scePthreadAttrGet | `implemented` | LibKernel::PthreadAttrGet | 1 | 0x1dc0087 |
| `f7uOxY9mM1U` |  | `implemented` | &LibKernel::g_stack_chk_guard | 0 |  |
| `vNe1w4diLCs` |  | `implemented` | LibKernel::tls_get_addr | 0 |  |

