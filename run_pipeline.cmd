@echo off
REM ==========================================================================
REM  run_pipeline.cmd - rebuild every FYP output on P: (RUN-02)
REM  Run from the repo root on the work PC (C:\FYP_Education).
REM  Edit SAS_EXE if SAS is installed somewhere else (docs\OPEN_QUESTIONS.md Q-09).
REM ==========================================================================
setlocal
set "PROJ=%~dp0"
set "SAS_EXE=C:\Program Files\SASHome\SASFoundation\9.4\sas.exe"

if not exist "%SAS_EXE%" (
  echo SAS not found at "%SAS_EXE%". Edit SAS_EXE in run_pipeline.cmd.
  exit /b 1
)

echo Running SAS pipeline...
"%SAS_EXE%" -sysin "%PROJ%sas\99_run_all.sas" -nosplash -noterminal -log "%TEMP%\fyp_run_all.log" -print "%TEMP%\fyp_run_all.lst"
if errorlevel 2 (
  echo SAS reported ERRORs. See the newest run_all_*.log in the logs folder on P:.
  exit /b 1
)

where Rscript >nul 2>nul
if errorlevel 1 (
  echo Rscript not on PATH - skipping R figures.
  goto :done
)

echo Running R figures...
pushd "%PROJ%"
Rscript R\21_plot_mt_stacked_bars.R
Rscript R\22_plot_died_by_edu.R
popd

:done
echo Done. Outputs are in P:\PeCAN Research\06 Individual Folders\Mackenzie Topper\FYP_Education
endlocal
