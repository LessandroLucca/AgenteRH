SELECT 
	fin.matricula AS Matricula, 
	CASE WHEN fin.ADMITIDO_MES=1 THEN TO_CHAR(fin.ADMISSAO,'DD/MM/YYYY') ELSE 'N/D' END AS Admissão, 
	COALESCE(fin.SINDICATO,'N/D') AS "Sindicato do Colaborador", 
	'05/2025' AS "Competência", 
	CASE WHEN fin.BENEFICIO_ATIVO=1 THEN least(fin.dias,fin.dias_uteis_trabalhados) ELSE 0 END AS Dias, 
	CASE WHEN fin.BENEFICIO_ATIVO=1 THEN fin.VALOR ELSE 0.0 END AS "VALOR DIÁRIO VR", 
	CASE WHEN fin.BENEFICIO_ATIVO=1 THEN (least(fin.dias,fin.dias_uteis_trabalhados) * fin.VALOR) ELSE 0.0 END AS TOTAL, 
	CASE WHEN fin.BENEFICIO_ATIVO=1 THEN (least(fin.dias,fin.dias_uteis_trabalhados) * fin.VALOR *0.8) ELSE 0.0 END AS "Custo empresa", 
	CASE WHEN fin.BENEFICIO_ATIVO=1 THEN (least(fin.dias,fin.dias_uteis_trabalhados) * fin.VALOR *0.2) ELSE 0.0 END AS "Desconto profissional", 
	COALESCE(fin.DESC_SITUACAO,'Sem observação (Não está ativo)') ||  
		CASE WHEN fin.ATIVO = 1 THEN ', Ativo' ELSE '' END ||  
		CASE WHEN fin.DESLIGADO = 1 THEN ', Desligado' ELSE '' END ||  
		CASE WHEN fin.DESLIGADO = 2 THEN ', Desligado parcial' ELSE '' END ||  
		CASE WHEN fin.FERIAS = 1 THEN ', Ferias ('||fin.DIAS_DE_FERIAS||' dias)' ELSE '' END ||  
		CASE WHEN fin.AFASTADO = 1 THEN ', Afastado' ELSE '' END ||  
		CASE WHEN fin.APRENDIZ = 1 THEN ', Aprendiz' ELSE '' END ||  
		CASE WHEN fin.ESTAGIO = 1 THEN ', Estagiário' ELSE '' END ||  
		CASE WHEN fin.EXTERIOR = 1 THEN ', Exterior' ELSE '' END || 
		CASE WHEN fin.SINDICALIZADO = 0 THEN ', Sem sindicato' ELSE ''  
	END AS "OBS GERAL" 
FROM (  
	SELECT 
		CASE  
			WHEN aux.DESLIGADO=2 THEN ( 
				SELECT COUNT(*) AS working_days 
				FROM GENERATE_SERIES(aux.ADMISSAO::date, aux.DATA_DEMISSAO::date, '1 day'::interval) AS d(day) 
				WHERE EXTRACT(ISODOW FROM d.day) BETWEEN 1 AND 5
			) 
			WHEN aux.DESLIGADO=1 THEN ( 
				SELECT 0 AS working_days 
			)
			WHEN aux.FERIAS=1 THEN (
				CASE 
					WHEN aux.DIAS_DE_FERIAS=5 THEN 15
					WHEN aux.DIAS_DE_FERIAS=10 THEN 12
					WHEN aux.DIAS_DE_FERIAS=15 THEN 9
					WHEN aux.DIAS_DE_FERIAS=20 THEN 5
					ELSE 0
				END
			)
			ELSE ( 
				SELECT COUNT(*) AS working_days 
				FROM GENERATE_SERIES(aux.ADMISSAO::date, aux.end_of_month::date, '1 day'::interval) AS d(day) 
				WHERE EXTRACT(ISODOW FROM d.day) BETWEEN 1 AND 5
			)
		END AS dias_uteis_trabalhados, 
		CASE WHEN ( 
			   aux.ATIVO=0 
			OR aux.DESLIGADO=1 
			OR aux.AFASTADO=1 
			OR aux.APRENDIZ=1 
			OR aux.EXTERIOR=1 
			OR aux.ESTAGIO=1 
		  ) AND aux.ADMITIDO_MES=0 THEN 0 ELSE 1 END  
		AS BENEFICIO_ATIVO, 
		aux.* 
	FROM ( 
		SELECT DISTINCT  
			mat.matricula, 
			CASE TRIM(atv.SINDICATO) 
				WHEN 'SINDPDSP' THEN 'SINDPD SP - SIND.TRAB.EM PROC DADOS E EMPR.EMPRESAS PROC DADOS ESTADO DE SP.' 
				WHEN 'SINDPDRJ' THEN 'SINDPD RJ - SINDICATO PROFISSIONAIS DE PROC DADOS DO RIO DE JANEIRO' 
				WHEN 'SITEPD' THEN 'SITEPD PR - SIND DOS TRAB EM EMPR PRIVADAS DE PROC DE DADOS DE CURITIBA E REGIAO METROPOLITANA' 
				WHEN 'SINDPPD' THEN 'SINDPPD RS - SINDICATO DOS TRAB. EM PROC. DE DADOS RIO GRANDE DO SUL' 
			END AS SINDICATO, 
			dias.UF, 
			COALESCE(adm.ADMISSAO, '2025-04-01'::date) AS ADMISSAO, 
			CASE WHEN dias.dias IS NOT NULL AND COALESCE(dias.dias,0)>0 
				THEN dias.dias
				ELSE (
					SELECT COUNT(*) AS working_days 
					FROM GENERATE_SERIES(date_trunc('month', '2025-04-01'::date), (date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day'), '1 day'::interval) AS d(day) 
					WHERE EXTRACT(ISODOW FROM d.day) BETWEEN 1 AND 5
				)
			END AS dias, 
			(date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day') AS end_of_month, 
			COALESCE(vlr.VALOR,(
				SELECT MIN(v.VALOR) AS VLR FROM BASE_SINDICATO_X_VALOR v WHERE v.VALOR > 0.0  
			)) as VALOR, 
			CASE WHEN COALESCE(atv.matricula, 0)>0 THEN 1 ELSE 0 END AS ATIVO, 
			CASE  
				WHEN COALESCE(des.matricula, 0)>0 AND des.COMUNICADO_DE_DESLIGAMENTO = 'OK' AND ( 
					NOT des.DATA_DEMISSAO>(date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day') 
				) AND ( 
					(  
						NOT des.DATA_DEMISSAO BETWEEN '2025-04-01'::date AND (date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day') 
					) OR (  
						des.DATA_DEMISSAO BETWEEN '2025-04-01'::date AND (date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day') 
						AND DATE_PART('day', des.DATA_DEMISSAO)<=15  
					) 
				) 
					THEN 1 
				WHEN COALESCE(des.matricula, 0)>0 AND des.COMUNICADO_DE_DESLIGAMENTO = 'OK' AND ( 
					des.DATA_DEMISSAO BETWEEN '2025-04-01'::date AND (date_trunc('month', '2025-04-01'::date) + interval '1 month' - interval '1 day') 
					AND DATE_PART('day', des.DATA_DEMISSAO)>15  
				) 
					THEN 2 
				ELSE 0 
			END AS DESLIGADO, 
			CASE WHEN atv.SINDICATO IS NULL THEN 0 ELSE 1 END AS SINDICALIZADO, 
			CASE WHEN COALESCE(fer.matricula, 0)>0 THEN 1 ELSE 0 END AS FERIAS, 
			CASE WHEN COALESCE(afa.matricula, 0)>0 THEN 1 ELSE 0 END AS AFASTADO, 
			CASE WHEN COALESCE(apr.matricula, 0)>0 THEN 1 ELSE 0 END AS APRENDIZ, 
			CASE WHEN COALESCE(adm.matricula, 0)>0 THEN 1 ELSE 0 END AS ADMITIDO_MES, 
			CASE WHEN COALESCE(ext.matricula, 0)>0 THEN 1 ELSE 0 END AS EXTERIOR, 
			CASE WHEN adm.cargo='ESTAGIARIO' OR est.TITULO_DO_CARGO='ESTAGIARIO' 
				THEN 1 ELSE 0  
			END	AS ESTAGIO, 
			des.DATA_DEMISSAO, 
			atv.DESC_SITUACAO,
			fer.DIAS_DE_FERIAS
		FROM MATRICULAS mat 
		LEFT OUTER JOIN ATIVOS atv 
			ON mat.matricula=atv.matricula 
		LEFT OUTER JOIN DESLIGADOS des 
			ON mat.matricula=des.matricula 
		LEFT OUTER JOIN ADMISSAO_ABRIL adm 
			ON mat.matricula=adm.matricula 
		LEFT OUTER JOIN AFASTAMENTOS afa 
			ON mat.matricula=afa.matricula 
		LEFT OUTER JOIN EXTERIOR ext 
			ON mat.matricula=ext.matricula 
		LEFT OUTER JOIN ESTAGIO est 
			ON mat.matricula=est.matricula 
		LEFT OUTER JOIN BASE_DIAS_UTEIS dias 
			ON atv.sindicato=dias.SINDICATO 
		LEFT OUTER JOIN BASE_SINDICATO_X_VALOR vlr 
			ON dias.UF=vlr.UF 
		LEFT OUTER JOIN FERIAS fer 
			ON mat.matricula=fer.matricula 
		LEFT OUTER JOIN APRENDIZ apr 
			ON mat.matricula=apr.matricula
	) aux
) fin 
ORDER BY matricula