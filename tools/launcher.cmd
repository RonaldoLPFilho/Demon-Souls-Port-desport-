@echo off
rem Launcher do desport (janela do tools\launcher.ps1): duplo clique; sem janela de console.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher.ps1" %*
