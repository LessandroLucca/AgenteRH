# Agentes Autônomos – Desafio 4 - Agente de RH para geração de folha de pagamento de Vale Refeição/Alimentação

# Requisitos
* NodeJs (npm)
* Python (pip)
* PostgreSQL
* LLM: Qwen, Llama, Granite, Mistral (Must be Tools compatible)
* Módulos Python: ollama, openpyxl, pandas, zipfile, os, csv

# Comandos para instalar as extensões do Python
> pip install openpyxl
> pip install pandas

Nesse repositório existem os seguintes arquivos:

* AgenteRH.json
* run.bat
* 1_XLSX_TO_CSV.py
* 2_CSV_TO_SQL.py
* custom_create_script.sql
* custom_querie.sql
* custom_schema_script.sql
* Desafio 4 - Dados.zip
* VR MENSAL 05.2025.xlsx

# AgenteRH.json
Arquivo JSON de um workflow, de um agente criado no N8N, o qual usa Ollama juntamente com o modelo o LLM qwen2.5vl:3b, para processar os dados das planilhas XLSX contidas no arquivo Desafio 4 - Dados.zip

Essa pipeline está programada para ser acionada a partir de três tipos diferentes de gatilhos: 

* Ao realizar o upload para diretório E:\shared (existe um listener que fica monitorando essa pasta)
* Ao acessar a URL do Web (P.Ex.: http://localhost:5678/webhook-test/14f459ae-8728-4551-813d-8cd6ae91f1c3)
* Ao receber uma chamada externa (P.Ex. Comando executado a partir da linha de comando: bash, shell ou CMD)

# run.bat
Script BAT que prepara os dados para serem consumidos pelo workflow do agente no N8N.
Depende dos seguintes utilitários (comandos) instalados no sistema:
* nodeJs
* N8N
* 7z
* grep
* sfk

OBS: Altere a seguinte linha do arquivo BAT com o ID do workflow cadastrado no N8N, para poder executar o agente corretamente localmente.

> SET WORKFLOW=abcdefghijklmnop

# Execute o comando run.bat para processar o agente
E:\run.bat 

# RESUMO DAS ETAPAS EXECUTADAS PELO run.bat

# Descompacta as planilhas para a pasta .\Dados
> 7z e -o".\dados" "Desafio 4 - Dados.zip"

# Executa o comando para converter as planilhas XLSX no diretório .\dados, para CSV no diretório atual
> python 1_XLSX_TO_CSV.py

# Executa o comando para gerar o script SQL contendo o esquema(CREATE TABLE apenas), para ser usado no prompt posteriormente (Será gerado o arquivo schema.sql)
> python 2_CSV_TO_SQL.py -o NOINSERT .\

# Executa o comando para gerar o script SQL completo, para migrar os dados do CSV para o banco PostgreSQL (Será gerado o arquivo script.sql)
> python 2_CSV_TO_SQL.py -o script.sql .\

# Executa o comando para popular os dados do CSV no banco agente_rh no PostgreSQL
> createdb -U postgres agente_rh
> psql -U postgres -d agente_rh -f .\script.sql

# Gera o arquivo ZIP temporário, contendo os parâmetros de entrada para o agente no N8N em E:\RH.zip
> 7z a %TMPZIP% %QUERIE% %PRMPTS% %SCHEMA% %TABLES%

OBS: O arquivo ZIP deve estar previamente gerado e presente na pasta E:\shared, para a execução do gatilho do Workflow

#Executa o comando para executar o workflow do N8N, para gerar a planilha de resultado VR MENSAL 05.2025.xlsx
> n8n execute --id %WORKFLOW%
