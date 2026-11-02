#!/usr/bin/env bash
# scripts/lab5/04-reto-curva.sh — reto de la Parte E: dibuja la curva del punto de equilibrio (SVG) a partir de la evidencia 04
# Lee la sección 3 de la última evidencia 04-agrupamiento-equilibrio y escribe un SVG con k y lecturas en escala logarítmica.
# Uso: bash scripts/lab5/04-reto-curva.sh
set -euo pipefail
source scripts/deployment/env/00-config.sh
EVID=$(ls -t "$EVID_LAB5"/script/*_04-agrupamiento-equilibrio.script.log | head -1)
SVG="$EVID_LAB5/config/$(ts)_04-reto-curva-equilibrio.svg"
mkdir -p "$EVID_LAB5/config"
awk '
function lg(v) { return log(v) / log(10) }
function px(k) { return 70 + (lg(k) + 2) / 4 * 640 }          # k de 0,01 % a 100 %
function py(v) { return 400 - lg(v) / 6.2 * 360 }             # lecturas de 1 a ~1,6 millones
function cruce(a1, a2, t1, t2, x1, x2,   d1, d2) {
  d1 = lg(a1) - lg(t1); d2 = lg(a2) - lg(t2)
  return x1 + (x2 - x1) * d1 / (d1 - d2)
}
/^\.?[0-9.]+ +%/ {
  n++; k[n] = $1 + 0; b[n] = $4; m[n] = $5; t[n] = $6
  opt[n] = ($0 ~ /recorrido/) ? "tabla" : "indice"
}
END {
  for (i = 1; i < n; i++) {
    if ((m[i] - t[i]) * (m[i+1] - t[i+1]) < 0) xm = cruce(m[i], m[i+1], t[i], t[i+1], lg(k[i]), lg(k[i+1]))
    if ((b[i] - t[i]) * (b[i+1] - t[i+1]) < 0) xb = cruce(b[i], b[i+1], t[i], t[i+1], lg(k[i]), lg(k[i+1]))
    if (opt[i] == "indice" && opt[i+1] == "tabla") xo = (lg(k[i]) + lg(k[i+1])) / 2
  }
  printf "cruce CF malo / tabla: k = %.2f %%\n", 10 ^ xm > "/dev/stderr"
  printf "cruce CF bueno / tabla: k = %.0f %%\n", 10 ^ xb > "/dev/stderr"
  printf "cambio del optimizador: k = %.2f %% (entre las dos medidas)\n", 10 ^ xo > "/dev/stderr"
  print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"760\" height=\"470\" font-family=\"sans-serif\" font-size=\"12\">"
  print "<rect width=\"760\" height=\"470\" fill=\"#ffffff\"/>"
  print "<text x=\"380\" y=\"22\" text-anchor=\"middle\" font-size=\"15\">Lecturas lógicas para sumar el importe del k % de los pedidos (TiendaSur)</text>"
  for (e = -2; e <= 2; e++) {
    x = px(10 ^ e); print "<line x1=\"" x "\" y1=\"40\" x2=\"" x "\" y2=\"400\" stroke=\"#dddddd\"/>"
    print "<text x=\"" x "\" y=\"418\" text-anchor=\"middle\">" (10 ^ e) " %</text>"
  }
  for (e = 0; e <= 6; e++) {
    y = py(10 ^ e); print "<line x1=\"70\" y1=\"" y "\" x2=\"710\" y2=\"" y "\" stroke=\"#dddddd\"/>"
    print "<text x=\"62\" y=\"" y + 4 "\" text-anchor=\"end\">1e" e "</text>"
  }
  print "<text x=\"390\" y=\"445\" text-anchor=\"middle\">k (% de filas, escala logarítmica)</text>"
  print "<text x=\"18\" y=\"220\" text-anchor=\"middle\" transform=\"rotate(-90 18 220)\">lecturas lógicas (escala logarítmica)</text>"
  linea("#555555", "6,4", t); linea("#d62728", "", m); linea("#1f77b4", "", b)
  xo_px = px(10 ^ xo)
  print "<line x1=\"" xo_px "\" y1=\"40\" x2=\"" xo_px "\" y2=\"400\" stroke=\"#2ca02c\" stroke-dasharray=\"3,3\"/>"
  print "<text x=\"" xo_px + 4 "\" y=\"54\" fill=\"#2ca02c\">el optimizador cambia a la tabla</text>"
  punto(10 ^ xm, t[1], "#d62728", "CF malo = tabla"); punto(10 ^ xb, t[1], "#1f77b4", "CF bueno = tabla")
  print "<rect x=\"80\" y=\"60\" width=\"190\" height=\"62\" fill=\"#ffffff\" stroke=\"#bbbbbb\"/>"
  leyenda(76, "#d62728", "", "índice con CF malo"); leyenda(94, "#1f77b4", "", "índice con CF bueno"); leyenda(112, "#555555", "6,4", "tabla entera")
  print "</svg>"
}
function linea(color, dash, v,   i, pts) {
  pts = ""; for (i = 1; i <= n; i++) pts = pts px(k[i]) "," py(v[i]) " "
  printf "<polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"%s/>\n", pts, color, (dash != "" ? " stroke-dasharray=\"" dash "\"" : "")
}
function punto(kk, v, color, txt) {
  printf "<circle cx=\"%s\" cy=\"%s\" r=\"5\" fill=\"%s\"/>\n", px(kk), py(v), color
  printf "<text x=\"%s\" y=\"%s\" fill=\"%s\" text-anchor=\"middle\">%s (%.2g %%)</text>\n", px(kk), py(v) + 20, color, txt, kk
}
function leyenda(y, color, dash, txt) {
  printf "<line x1=\"90\" y1=\"%s\" x2=\"120\" y2=\"%s\" stroke=\"%s\" stroke-width=\"2\"%s/>\n", y, y, color, (dash != "" ? " stroke-dasharray=\"" dash "\"" : "")
  printf "<text x=\"128\" y=\"%s\">%s</text>\n", y + 4, txt
}
' "$EVID" > "$SVG"
echo "Curva escrita en $SVG (a partir de $EVID)"
