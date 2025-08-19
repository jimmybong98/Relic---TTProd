from flask import Flask, request, jsonify
from openpyxl import load_workbook
import re
import time

app = Flask(__name__)

# ======== CONFIG ========
PLANILHA_PREPARADOR_PATH = (
    r"\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 007 - Registro de amostragem e For - 008 - Liberação de Maquina 4.xlsx"
)
PLANILHA_OPERADOR_PATH = (
    r"\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 09 a 14 - Verificação durante o Processo 2.xlsx"
)

ABA_PREPARADOR = "CADASTRO"
ABA_OPERADOR = "CADASTRO"

COL_MEDIDAS_INICIO = 6
# Preparador usa coluna A
COL_CHAVE_COMBINADA_PREPARADOR = 0
# Operador usa coluna C
COL_CHAVE_COMBINADA_OPERADOR = 2

COLS_CHAVE_SEPARADAS = None  # não usamos aqui


# ======== HELPERS ========
def _norm(text):
    return (str(text or "")).strip()

def _only_digits(text):
    s = re.sub(r"\D+", "", str(text or ""))
    return str(int(s)) if s else ""

def _keys_match(cell_value: str, part: str, op: str) -> bool:
    s = _norm(cell_value)
    if "*" not in s:
        return False
    left, right = s.split("*", 1)
    return _only_digits(left) == _only_digits(part) and _only_digits(right) == _only_digits(op)

def _parse_range(texto: str):
    if not texto:
        return (None, None, None)
    s = str(texto)
    m = re.search(
        r"(-?\d+[.]?\d*)\s*(?:-|–|a|até)\s*(-?\d+[.]?\d*)\s*([^\d\s]+.*)?$",
        s, flags=re.IGNORECASE
    )
    if not m:
        m1 = re.search(r"(-?\d+[.,]?\d*)\s*([^\d\s]+.*)?$", s)
        if m1:
            v = _to_float(m1.group(1))
            uni = (m1.group(2) or "").strip() or None
            return (v, v, uni)
        return (None, None, None)
    v1 = _to_float(m.group(1))
    v2 = _to_float(m.group(2))
    uni = (m.group(3) or "").strip() or None
    if v1 is not None and v2 is not None and v1 > v2:
        v1, v2 = v2, v1
    return (v1, v2, uni)

def _to_float(s):
    try:
        return float(str(s).replace(",", ".").strip())
    except Exception:
        return None

def _row_values(ws, row_idx):
    return [c.value for c in ws[row_idx]]

def _encontrar_linha(ws, part: str, op: str, col_chave: int):
    part_d = _only_digits(part)
    op_d = _only_digits(op)
    for r in range(1, ws.max_row + 1):
        vals = _row_values(ws, r)
        cel = vals[col_chave] if col_chave < len(vals) else ""
        if _keys_match(cel, part, op):
            return vals
    return None

def _cell_text(row_vals, col_idx):
    return (str(row_vals[col_idx]) if col_idx < len(row_vals) and row_vals[col_idx] is not None else "").strip()

def _extrair_medidas_pares(row_vals):
    medidas = []
    col = COL_MEDIDAS_INICIO
    while True:
        etiqueta = _cell_text(row_vals, col)
        faixa = _cell_text(row_vals, col + 1)
        if not (etiqueta or faixa):
            break
        mn, mx, uni = _parse_range(faixa)
        medidas.append({
            "titulo": etiqueta or "",
            "faixaTexto": faixa or "",
            "min": mn,
            "max": mx,
            "unidade": uni,
        })
        col += 2
    return medidas

def _extrair_medidas_quartetos(row_vals):
    medidas = []
    col = COL_MEDIDAS_INICIO
    while True:
        tipo = _cell_text(row_vals, col)
        faixa = _cell_text(row_vals, col + 1)
        periodic = _cell_text(row_vals, col + 2)
        instrumento = _cell_text(row_vals, col + 3)
        if not (tipo or faixa or periodic or instrumento):
            break
        mn, mx, uni = _parse_range(faixa)
        medidas.append({
            "titulo": tipo or "",
            "faixaTexto": faixa or "",
            "min": mn,
            "max": mx,
            "unidade": uni,
            "periodicidade": periodic or "",
            "instrumento": instrumento or "",
        })
        col += 4
    return medidas

def _buscar_medidas(path: str, aba: str, part: str, op: str, extrator, col_chave: int):
    wb = None
    try:
        wb = load_workbook(path, data_only=True, read_only=True)
        if aba not in wb.sheetnames:
            raise RuntimeError(f"Aba '{aba}' não encontrada")
        ws = wb[aba]
        row_vals = _encontrar_linha(ws, part, op, col_chave)
        if row_vals is None:
            return []
        return extrator(row_vals)
    finally:
        try:
            if wb:
                wb.close()
        except Exception:
            pass

# ======== ROUTES ========
@app.route("/preparador/medidas")
def medidas_preparador():
    part = _norm(request.args.get("partnumber"))
    op = _norm(request.args.get("operacao"))
    if not part or not op:
        return jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}), 400
    print(f"[DEBUG] /preparador/medidas chamado: part={part}, op={op}", flush=True)
    try:
        data = _buscar_medidas(
            PLANILHA_PREPARADOR_PATH,
            ABA_PREPARADOR,
            part,
            op,
            _extrair_medidas_pares,
            COL_CHAVE_COMBINADA_PREPARADOR
        )
        if not data:
            return jsonify({"error": "Nenhuma medida encontrada para os parâmetros informados"}), 404
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": f"Falha ao ler planilha do PREPARADOR: {e}"}), 500

@app.route("/operador/medidas")
def medidas_operador():
    part = _norm(request.args.get("partnumber"))
    op = _norm(request.args.get("operacao"))
    if not part or not op:
        return jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}), 400
    print(f"[DEBUG] /operador/medidas chamado: part={part}, op={op}", flush=True)
    try:
        data = _buscar_medidas(
            PLANILHA_OPERADOR_PATH,
            ABA_OPERADOR,
            part,
            op,
            _extrair_medidas_quartetos,
            COL_CHAVE_COMBINADA_OPERADOR
        )
        if not data:
            return jsonify({"error": "Nenhuma medida encontrada para os parâmetros informados"}), 404
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": f"Falha ao ler planilha do OPERADOR: {e}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5005, debug=True, threaded=True)
