import os
import csv
import re
import unicodedata
import argparse
from collections import defaultdict

# --- Funções de Limpeza e Formatação ---

def slugify(text):
    """
    Normaliza o texto para ser usado como um identificador SQL seguro.
    Regras aplicadas:
    1. Remove acentuação.
    2. Substitui caracteres não alfanuméricos por sublinhado.
    3. Remove sublinhados duplicados.
    4. Remove sublinhados no início ou fim.
    """
    if not text:
        return ""
    # 1. Remove a acentuação
    text = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('utf-8')
    # 2. Substitui caracteres estranhos e espaços por sublinhado
    text = re.sub(r'[^a-zA-Z0-9]+', '_', text)
    # 3. Remove múltiplos sublinhados
    text = re.sub(r'_+', '_', text)
    # 4. Remove sublinhados no início/fim
    text = text.strip('_')
    return text

def sanitize_column_name(name):
    """
    Aplica as regras de sanitização específicas para nomes de colunas e
    converte para maiúsculas.
    """
    if not name:
        return "COLUNA_SEM_NOME"
    
    # Regra 3: Adequar ou escapar aspas (removendo-as)
    name = name.replace('"', '').replace("'", "")
    
    # Aplica as outras regras (espaços, acentos, caracteres estranhos)
    # e converte para caixa alta.
    return slugify(name).upper()

def format_sql_value(value):
    """
    Formata um valor Python para ser inserido em uma cláusula INSERT.
    - Trata valores nulos.
    - Escapa aspas simples em strings.
    - Retorna números e booleanos sem aspas.
    """
    if value is None or value.strip() == '':
        return "NULL"
    
    # Para strings, escapa a aspa simples (') duplicando-a ('')
    # e envolve o valor com aspas simples.
    escaped_value = value.replace("'", "''")
    return f"'{escaped_value}'"

# --- Funções de Inferência de Tipo de Dados ---

def infer_data_type(value):
    """
    Tenta inferir o tipo de dado PostgreSQL mais apropriado para um único valor.
    """
    if value is None or value.strip() == '':
        return None  # Não podemos inferir nada de um valor vazio

    # Tenta converter para inteiro
    try:
        int(value)
        return 'INTEGER'
    except ValueError:
        pass

    # Tenta converter para numérico (float/decimal)
    try:
        float(value)
        return 'NUMERIC'
    except ValueError:
        pass

    # Verifica se é booleano
    if value.lower() in ['true', 'false', 't', 'f', '1', '0']:
        return 'BOOLEAN'

    # Verifica formatos comuns de data e timestamp
    # A ordem é importante: timestamp é mais específico que date.
    # YYYY-MM-DD HH:MM:SS
    if re.match(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$', value):
        return 'TIMESTAMP'
    # YYYY-MM-DD
    if re.match(r'^\d{4}-\d{2}-\d{2}$', value):
        return 'DATE'

    # Se nada mais funcionar, é texto
    return 'TEXT'

def get_best_fit_type(types):
    """
    Determina o melhor tipo de dado de uma lista de tipos inferidos para uma coluna.
    A hierarquia de prioridade é: TEXT > NUMERIC > INTEGER > BOOLEAN > DATE > TIMESTAMP
    Se 'TEXT' estiver presente, a coluna inteira deve ser TEXT.
    """
    priority_order = ['TEXT', 'NUMERIC', 'TIMESTAMP', 'DATE', 'INTEGER', 'BOOLEAN']
    
    # Remove os Nones, que representam células vazias
    valid_types = [t for t in types if t]
    if not valid_types:
        return 'TEXT' # Coluna com todas as células vazias

    # Encontra o tipo de maior prioridade na lista de tipos da coluna
    for p_type in priority_order:
        if p_type in valid_types:
            return p_type
    
    return 'TEXT' # Fallback

# --- Função Principal de Processamento ---

def generate_sql_from_csv(directory_path, output_file):
    """
    Função principal que lê os arquivos CSV e gera o script SQL.
    """
    final_sql = []
    
    try:
        files = [f for f in os.listdir(directory_path) if f.lower().endswith('.csv')]
        if not files:
            print(f"Aviso: Nenhum arquivo .csv encontrado no diretório '{directory_path}'.")
            return
    except FileNotFoundError:
        print(f"Erro: O diretório '{directory_path}' não foi encontrado.")
        return

    for filename in files:
        file_path = os.path.join(directory_path, filename)
        
        # Usa o nome do arquivo (sem extensão) como nome da tabela
        table_name = sanitize_column_name(os.path.splitext(filename)[0])
        
        print(f"Processando arquivo: {filename} -> Tabela: {table_name}")

        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f)
                
                # Extrai o cabeçalho
                try:
                    header = next(reader)
                    sanitized_headers = [sanitize_column_name(h) for h in header]
                except StopIteration:
                    print(f"  Aviso: O arquivo '{filename}' está vazio ou não tem cabeçalho. Pulando.")
                    continue

                # Lê todas as linhas de dados para inferir os tipos
                data_rows = list(reader)
                if not data_rows:
                    print(f"  Aviso: O arquivo '{filename}' não contém dados após o cabeçalho. Apenas CREATE TABLE será gerado.")
                
                # Inferência de tipos de dados
                column_types = defaultdict(list)
                for row in data_rows:
                    # Garante que a linha tenha o mesmo número de colunas que o cabeçalho
                    if len(row) != len(sanitized_headers):
                        continue # Pula linhas malformadas
                    for i, cell in enumerate(row):
                        inferred_type = infer_data_type(cell)
                        column_types[i].append(inferred_type)
                
                final_column_types = [get_best_fit_type(column_types[i]) for i in range(len(sanitized_headers))]

                # Monta a cláusula CREATE TABLE
                # create_table_sql = f"\n-- Tabela gerada a partir de {filename}\n"
                create_table_sql = f"\n"
                create_table_sql += f"CREATE TABLE IF NOT EXISTS {table_name} (\n"
                column_definitions = []
                for i, col_name in enumerate(sanitized_headers):
                    col_type = final_column_types[i]
                    column_definitions.append(f"    {col_name} {col_type}")
                create_table_sql += ",\n".join(column_definitions)
                create_table_sql += "\n);\n"
                final_sql.append(create_table_sql)
                
                # Monta as cláusulas INSERT
                if output_file!="schema.sql":
                    if data_rows:
                        insert_sql = f"INSERT INTO {table_name} ({', '.join(sanitized_headers)}) VALUES\n"
                        value_lines = []
                        for row in data_rows:
                            if len(row) == len(sanitized_headers):
                                formatted_values = [format_sql_value(cell) for cell in row]
                                value_lines.append(f"    ({', '.join(formatted_values)})")
                        
                        if value_lines:
                            insert_sql += ",\n".join(value_lines)
                            insert_sql += ";\n"
                            final_sql.append(insert_sql)

        except Exception as e:
            print(f"  Erro ao processar o arquivo '{filename}': {e}")

    # Escreve o script SQL final no arquivo de saída
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("".join(final_sql))
        print(f"\nScript SQL gerado com sucesso em: '{output_file}'")
    except Exception as e:
        print(f"\nErro ao escrever o arquivo de saída '{output_file}': {e}")


# --- Execução do Script ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Converte arquivos CSV de um diretório para um script SQL de criação de banco de dados PostgreSQL.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "diretorio",
        help="Caminho para o diretório contendo os arquivos CSV."
    )
    parser.add_argument(
        "-o", "--output",
        default="script_gerado.sql",
        help="Nome do arquivo SQL de saída. (Padrão: script_gerado.sql)"
    )
    args = parser.parse_args()
    generate_sql_from_csv(args.diretorio, args.output)
