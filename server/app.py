# server/app.py
from flask import Flask, request, jsonify
from openpyxl import load_workbook
from pathlib import Path
import re
from flask_cors import CORS

app = Flask(__name__)
app.url_map.strict_slashes = False  # aceita URLs com ou sem barra final
CORS(app)

# ========================= CONFIG =========================
PLANILHA_PREPARADOR_PATH = (
    r"\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 007 - Registro de amostragem e For - 008 - Liberação de Maquina 4.xlsx"
)
PLANILHA_OPERADOR_PATH = (
    r"\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 09 a 14 - Verificação durante o Processo 2.xlsx"
)

ABA_PREPARADOR = "CADASTRO"
ABA_OPERADOR = "CADASTRO"

COL_MEDIDAS_INICIO = 6  # G=6, H=7, I=8, J=9...
COL_CHAVE_COMBINADA = 0
COLS_CHAVE_SEPARADAS = None  # ex.: (0,1) se tiver colunas separadas

# ========================= HELPERS =========================
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
        r"(-?\d+[.,]?\d*)\s*(?:-|–|a|até)\s*(-?\d+[.,]?\d*)\s*([^\d\s]+.*)?$",
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

def _encontrar_linha(ws, part: str, op: str):
    part_d = _only_digits(part)
    op_d = _only_digits(op)
    for r in range(1, ws.max_row + 1):
        vals = _row_values(ws, r)
        if COLS_CHAVE_SEPARADAS:
            i_part, i_op = COLS_CHAVE_SEPARADAS
            vpart = _only_digits(vals[i_part] if i_part < len(vals) else "")
            vop = _only_digits(vals[i_op] if i_op < len(vals) else "")
            if vpart == part_d and vop == op_d:
                return vals
        else:
            cel = vals[COL_CHAVE_COMBINADA] if COL_CHAVE_COMBINADA < len(vals) else ""
            if _keys_match(cel, part, op):
                return vals
    return None

def _cell_text(row_vals, col_idx):
    return (str(row_vals[col_idx]) if col_idx < len(row_vals) and row_vals[col_idx] is not None else "").strip()


def _get_arg(*names):
    """Retorna o primeiro parâmetro presente na query string, normalizado.

    Permite utilizar diferentes variações de nomes (ex.: partnumber vs partNumber).
    """
    for name in names:
        if name in request.args:
            return _norm(request.args[name])
    return ""

# ----------------- Extratores ------------------
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
            "etiqueta": etiqueta or "",
            "faixa": faixa or "",
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
            "tipo": tipo or "",
            "faixa": faixa or "",
            "min": mn,
            "max": mx,
            "unidade": uni,
            "periodicidade": periodic or "",
            "instrumento": instrumento or "",
        })
        col += 4
    return medidas

# ========================= ROTAS ==========================
@app.get("/")
def index():
    return jsonify({"ok": True, "service": "medidas-api"})

@app.get("/health")
def health():
    return jsonify({
        "preparador_path": PLANILHA_PREPARADOR_PATH,
        "operador_path": PLANILHA_OPERADOR_PATH,
        "aba_preparador": ABA_PREPARADOR,
        "aba_operador": ABA_OPERADOR
    })

@app.get("/medidas")
def get_medidas_preparador():
    part = _get_arg("partnumber", "partNumber")
    op = _get_arg("operacao", "operation")
    if not part or not op:
        return jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}), 400
    try:
        wb = load_workbook(PLANILHA_PREPARADOR_PATH, data_only=True, read_only=True)
        if ABA_PREPARADOR not in wb.sheetnames:
            return jsonify({"error": f"Aba '{ABA_PREPARADOR}' não encontrada"}), 500
        ws = wb[ABA_PREPARADOR]
        row_vals = _encontrar_linha(ws, part, op)
        if row_vals is None:
            return jsonify([])
        return jsonify(_extrair_medidas_pares(row_vals))
    except Exception as e:
        return jsonify({"error": f"Falha ao ler planilha do PREPARADOR: {e}"}), 500

@app.get("/operador/medidas")
def get_medidas_operador():
    part = _get_arg("partnumber", "partNumber")
    op = _get_arg("operacao", "operation")
    if not part or not op:
        return jsonify({"error": "Parâmetros 'partnumber' e 'operacao' são obrigatórios"}), 400
    try:
        wb = load_workbook(PLANILHA_OPERADOR_PATH, data_only=True, read_only=True)
        if ABA_OPERADOR not in wb.sheetnames:
            return jsonify({"error": f"Aba '{ABA_OPERADOR}' não encontrada"}), 500
        ws = wb[ABA_OPERADOR]
        row_vals = _encontrar_linha(ws, part, op)
        if row_vals is None:
            return jsonify([])
        return jsonify(_extrair_medidas_quartetos(row_vals))
    except Exception as e:
        return jsonify({"error": f"Falha ao ler planilha do OPERADOR: {e}"}), 500


@app.post("/resultado")
def post_resultado_preparador():
    """Recebe o resultado de medições do preparador.

    Neste protótipo os dados são apenas retornados como confirmação.
    """
    data = request.get_json(silent=True) or {}
    return jsonify({"status": "ok", "received": data})


@app.post("/operador/resultado")
def post_resultado_operador():
    """Recebe o resultado de medições do operador."""
    data = request.get_json(silent=True) or {}
    return jsonify({"status": "ok", "received": data})

# ========================= MAIN ==========================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5005, debug=False, threaded=True)
