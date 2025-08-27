@echo off

:: REQUIREMENTS - before the execution of this current .BAT script
:: ===============================================================
:: N8N JSON workflow imported (update WORKFLOW_ID environment on line 15)
:: N8N started with workflow running and awaiting (TO DEBUG) *OR* Uncommented line 95
:: The file %USRZIP% must be in the same current folder
:: The Python script files must be in the same current folder
SET N8N_RUNNERS_ENABLED=true

:: USER CUSTOM PARAMERS AND FILES
:: ==============================

:: N8N workflow_id - hosted and running on localhost:5678 N8N instance
SET WORKFLOW=abcdefghijklmnop
SET DBNAME=agente_rh
SET PRMPTS=rules_prompt.txt
SET USRZIP=Desafio 4 - Dados.zip
SET CSFILE=VR_MENSAL_05.2025.csv
SET XLFILE=VR MENSAL 05.2025.xlsx

:: Python tools scripts
SET XLS_TO_CSV=1_XLSX_TO_CSV.py
SET CSV_TO_SQL=2_CSV_TO_SQL.py
SET CSV_TO_XLS=3_CSV_TO_XLSX.py

:: Runtime parameters (path, temp files)
SET RELDIR=.\dados
SET TMPZIP=E:\shared\RH.zip
SET TABLES=tables.sql
SET SCHEMA=schema.sql
SET SCRIPT=script.sql
SET MAKEDB=create.sql
SET QUERIE=querie.sql

CALL :CLEAR

CALL :ERASE_TEMP_FILES

:: extract user zip file content to user folder (%RELDIR%)
7z -y e -o"%RELDIR%" "%USRZIP%"
del /Q "%RELDIR%%XLFILE%"

:: Executa o comando que converte as planilhas XLSX presentes no diretório relativo .\dados, para CSV no diretório atual
python %XLS_TO_CSV%

:: Executa o comando para gerar o script SQL (schema.sql) contendo apenas o esquema de CREATE, para ser usado no prompt posteriormente
python %CSV_TO_SQL% -o %SCHEMA% .\

:: Executa o comando para gerar o script SQL completo, para migrar os dados do CSV para o banco PostgreSQL (Será gerado o arquivo script.sql)
python %CSV_TO_SQL% -o %SCRIPT% .\

:: bypass to use custom scripts
cp custom_create_%SCRIPT% %SCRIPT%
cp custom_schema_%SCRIPT% %SCHEMA%
cp custom_%QUERIE% %QUERIE%  
::Comment follow line to bypass query gen by AI Agent node on workflow 
type nul > %QUERIE%

:: Executa o comando para migrar os dados do CSV para o banco PostgreSQL
createdb -U postgres %DBNAME%
psql -U postgres -d %DBNAME% -f %SCRIPT%

cat %SCHEMA% | grep "CREATE"|awk -F" " "{print $6}">%TABLES%

:: add separator at end of files (=== is wildcard character sequence defined/used by N8N workflow) 
echo ===>>%QUERIE%
echo ===>>%SCHEMA%

:: create zip file with compressed contents used to parse parameters to workflow 
7z a %TMPZIP% %QUERIE% %PRMPTS% %SCHEMA% %TABLES%   
cp %TMPZIP% E:\

echo:
echo Processando! Aguarde...

:: Executa o comando para executar o workflow do N8N, para gerar a planilha de resultado
n8n execute --id %WORKFLOW%

CALL :EXIT

:: clean runtime files
:ERASE_TEMP_FILES
del /Q %TMPZIP%
del /Q %CSFILE%
del /Q %TABLES%
del /Q %SCHEMA%
del /Q %SCRIPT%
del /Q %QUERIE%
del /Q *.csv
rmdir /Q /S %RELDIR%
GOTO:EOF

:CLEAN_SCREEN
cls
GOTO:EOF

:: clean runtime environment vars
:CLEAN_ENV
SET WORKFLOW=
SET DBNAME=
SET PRMPTS=
SET USRZIP=
SET CSFILE=
SET XLFILE=
SET XLS_TO_CSV=
SET CSV_TO_SQL=
SET CSV_TO_XLS=
SET RELDIR=
SET TMPZIP=
SET TABLES=
SET SCHEMA=
SET SCRIPT=
SET MAKEDB=
SET QUERIE=
GOTO:EOF

:EXIT
echo Aguarde o inicio do Processamento pelo N8N
pause
CALL :ERASE_TEMP_FILES
CALL :CLEAN_ENV
CALL :CLEAN_SCREEN
echo:
echo Fim do Processamento
exit /b