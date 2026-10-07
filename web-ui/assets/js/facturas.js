"use strict";

function resolveApiBase() {
    if (!window.location.protocol.startsWith("http")) {
        return null;
    }

    const path = window.location.pathname;
    const idx = path.lastIndexOf("/web-ui/");

    if (idx !== -1) {
        return window.location.origin + path.substring(0, idx) + "/api";
    }

    return window.location.origin + "/api";
}

const API_BASE = resolveApiBase() || "/api";
const API_URL = `${API_BASE}/facturas.php`;
const OCR_IDIOMA = "spa";
const PDFJS_WORKER =
    "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";
const CLAVE_TIPO_CAMBIO = "portico_tipo_cambio_usd";

const OBRAS_DEMO = [
    { id_obra: 1, nombre: "Obra Rivera Centro" },
    { id_obra: 2, nombre: "Obra Barrio Mandubí" },
    { id_obra: 3, nombre: "Obra Zona Terminal" }
];

let itemsFactura = [];
let facturas = [];
/* false = usa api/facturas.php; true = datos de demostración sin servidor */
let modoDemo = false;

let csrfToken = "";

let ocrEnCurso = false;
let ocrUsado = false;
let ocrTexto = "";

document.addEventListener("DOMContentLoaded", () => {
    inicializar();
});

function inicializar() {
    configurarCargaArchivo();
    configurarTipoGasto();
    configurarMoneda();
    configurarPorcentajes();
    configurarItems();
    configurarTotales();
    configurarBotones();
    configurarFiltros();

    agregarItem();

    document.getElementById("fechaEmision").value = hoyLocal();
    document.getElementById("periodoDistribucion").value =
        hoyLocal().slice(0, 7);

    cargarObras();
    cargarFacturas();
}

function hoyLocal() {
    const d = new Date();
    const mes = String(d.getMonth() + 1).padStart(2, "0");
    const dia = String(d.getDate()).padStart(2, "0");

    return `${d.getFullYear()}-${mes}-${dia}`;
}

function redondear2(valor) {
    return Math.round((Number(valor) || 0) * 100) / 100;
}

/* ------------------------------------------------------------------ */
/* CARGA DE ARCHIVO Y LECTURA AUTOMÁTICA                               */
/* ------------------------------------------------------------------ */

function configurarCargaArchivo() {
    const input = document.getElementById("archivoFactura");
    const box = document.getElementById("uploadBox");
    const btn = document.getElementById("btnSeleccionarArchivo");

    btn.addEventListener("click", () => input.click());

    input.addEventListener("change", () => {
        mostrarArchivo(input.files[0]);

        if (input.files.length) {
            procesarOCR();
        }
    });

    ["dragenter", "dragover"].forEach(eventName => {
        box.addEventListener(eventName, e => {
            e.preventDefault();
            box.classList.add("dragover");
        });
    });

    ["dragleave", "drop"].forEach(eventName => {
        box.addEventListener(eventName, e => {
            e.preventDefault();
            box.classList.remove("dragover");
        });
    });

    box.addEventListener("drop", e => {
        const file = e.dataTransfer.files[0];

        if (!file) return;

        input.files = e.dataTransfer.files;
        mostrarArchivo(file);
        procesarOCR();
    });
}

function mostrarArchivo(file) {
    const container = document.getElementById("archivoSeleccionado");

    ocrUsado = false;
    ocrTexto = "";

    if (!file) {
        container.classList.add("hidden");
        container.textContent = "";
        return;
    }

    const sizeMB = (file.size / (1024 * 1024)).toFixed(2);

    container.innerHTML = `
        <i class="fa-solid fa-file"></i>
        ${escapeHtml(file.name)} (${sizeMB} MB)
    `;

    container.classList.remove("hidden");
}

async function procesarOCR() {
    const input = document.getElementById("archivoFactura");

    if (!input.files.length) {
        mostrarFeedback(
            "Seleccioná primero una imagen o PDF de la factura.",
            "warning"
        );

        return;
    }

    if (ocrEnCurso) return;

    ocrEnCurso = true;
    bloquearBotonOCR(true);

    const file = input.files[0];

    try {
        mostrarFeedback("Leyendo la factura...", "info", 0);

        const texto = await extraerTextoArchivo(file, progreso => {
            mostrarFeedback(
                `Leyendo la factura... ${Math.round(progreso * 100)}%`,
                "info",
                0
            );
        });

        const datos = interpretarTextoFactura(texto);
        datos.texto_ocr = texto;

        const resultado = cargarResultadoOCR(datos);

        ocrUsado = true;
        ocrTexto = datos.texto_ocr || "";

        informarResultadoOCR(resultado);

    } catch (error) {
        mostrarFeedback(
            error.message ||
            "No se pudo leer la factura. Podés completar los datos manualmente.",
            "error"
        );
    } finally {
        ocrEnCurso = false;
        bloquearBotonOCR(false);
    }
}

function bloquearBotonOCR(bloqueado) {
    const btn = document.getElementById("btnProcesarOCR");

    btn.disabled = bloqueado;
    btn.style.opacity = bloqueado ? "0.6" : "";
    btn.style.cursor = bloqueado ? "wait" : "";
}

function informarResultadoOCR(resultado) {
    const faltantes = [];

    if (!resultado.proveedor) faltantes.push("proveedor");
    if (!resultado.fecha) faltantes.push("fecha de emisión");
    if (!resultado.items) faltantes.push("detalle");

    if (resultado.items === 0 && resultado.campos === 0) {
        mostrarFeedback(
            "No se pudo reconocer texto en el archivo. " +
            "Probá con una imagen más nítida o completá los datos manualmente.",
            "warning"
        );

        return;
    }

    if (faltantes.length) {
        mostrarFeedback(
            `Se leyó la factura, pero no se pudo detectar: ${faltantes.join(", ")}. ` +
            "Completalo manualmente antes de guardar.",
            "warning"
        );

        return;
    }

    if (resultado.advertencia) {
        mostrarFeedback(resultado.advertencia, "warning");
        return;
    }

    if (resultado.moneda === "USD") {
        mostrarFeedback(
            "Factura en dólares leída. Ingresá el tipo de cambio y revisá " +
            "los datos antes de guardar.",
            "warning",
            8000
        );

        return;
    }

    mostrarFeedback(
        "Factura leída. Revisá los datos completados antes de guardar.",
        "success"
    );
}

/* ---------- Extracción de texto (imagen / PDF) ---------- */

async function extraerTextoArchivo(file, onProgress) {
    const esPDF =
        file.type === "application/pdf" || /\.pdf$/i.test(file.name);

    return esPDF
        ? extraerTextoPDF(file, onProgress)
        : reconocerConTesseract(file, onProgress);
}

async function reconocerConTesseract(fuente, onProgress) {
    if (typeof Tesseract === "undefined") {
        throw new Error(
            "No se pudo cargar el motor de lectura (Tesseract). " +
            "Verificá la conexión a internet."
        );
    }

    const { data } = await Tesseract.recognize(fuente, OCR_IDIOMA, {
        logger: m => {
            if (m.status === "recognizing text" && onProgress) {
                onProgress(m.progress || 0);
            }
        }
    });

    return data.text || "";
}

async function extraerTextoPDF(file, onProgress) {
    if (typeof pdfjsLib === "undefined") {
        throw new Error(
            "No se pudo cargar el lector de PDF. " +
            "Verificá la conexión a internet."
        );
    }

    pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER;

    const pdf = await pdfjsLib.getDocument({
        data: await file.arrayBuffer()
    }).promise;

    const paginas = Math.min(pdf.numPages, 3);
    let texto = "";

    for (let i = 1; i <= paginas; i++) {
        const page = await pdf.getPage(i);
        let textoPagina = await textoDePaginaPDF(page);

        // PDF escaneado (sin texto): se dibuja la página y se aplica OCR.
        if (textoPagina.replace(/\s/g, "").length < 40) {
            const viewport = page.getViewport({ scale: 2 });
            const canvas = document.createElement("canvas");

            canvas.width = viewport.width;
            canvas.height = viewport.height;

            await page.render({
                canvasContext: canvas.getContext("2d"),
                viewport
            }).promise;

            textoPagina = await reconocerConTesseract(canvas, progreso => {
                if (onProgress) {
                    onProgress(((i - 1) + progreso) / paginas);
                }
            });
        }

        texto += textoPagina + "\n";
    }

    return texto;
}

async function textoDePaginaPDF(page) {
    const content = await page.getTextContent();
    const lineas = new Map();

    content.items.forEach(item => {
        if (!item.str || !item.str.trim()) return;

        const y = Math.round(item.transform[5] / 3);
        const x = item.transform[4];

        if (!lineas.has(y)) lineas.set(y, []);
        lineas.get(y).push({ x, str: item.str });
    });

    return [...lineas.entries()]
        .sort((a, b) => b[0] - a[0])
        .map(([, partes]) =>
            partes
                .sort((a, b) => a.x - b.x)
                .map(p => p.str)
                .join(" ")
        )
        .join("\n");
}

/* ---------- Interpretación del texto ---------- */

function interpretarTextoFactura(texto) {
    const lineas = String(texto || "")
        .split(/\r?\n/)
        .map(l => l.replace(/\s+/g, " ").trim())
        .filter(Boolean);

    const plano = lineas.join("\n");

    const items = detectarItems(lineas);
    const sumaItems = items.reduce(
        (s, i) => s + i.cantidad * i.precio_unitario,
        0
    );
    const sumaBruto = items.reduce((s, i) => s + i.subtotal_linea, 0);
    const lineasConIva = items.some(i => i.tasa_iva > 0);

    let subtotal = null;
    let iva = null;
    let total = null;

    if (items.length && lineasConIva) {
        // e-Factura: P.UNIT es neto y SUB.TOTAL de cada línea incluye IVA
        subtotal = redondear2(sumaItems);
        total = redondear2(sumaBruto);
        iva = redondear2(total - subtotal);
    } else {
        subtotal = buscarMonto(
            lineas,
            /sub\s*-?\s*total|neto|base imponible/i
        );
        iva = buscarMonto(lineas, /\biva\b|i\.v\.a/i, true);
        total = buscarMonto(
            lineas,
            /\btotal\b/i,
            false,
            /sub|iva|i\.v\.a|descuento/i
        );

        if (subtotal === null && items.length) subtotal = sumaItems;
        if (subtotal === null && total !== null && iva !== null) {
            subtotal = total - iva;
        }
        if (iva === null && total !== null && subtotal !== null && total >= subtotal) {
            iva = total - subtotal;
        }
    }

    if (!items.length && subtotal !== null) {
        items.push({
            descripcion: "Según factura",
            cantidad: 1,
            precio_unitario: subtotal
        });
    }

    let advertencia = "";

    if (
        items.length &&
        subtotal !== null &&
        Math.abs(sumaItems - subtotal) > Math.max(1, subtotal * 0.02) &&
        items[0].descripcion !== "Según factura"
    ) {
        advertencia =
            "Se leyó la factura, pero el detalle no coincide con el subtotal. " +
            "Revisá los ítems antes de guardar.";
    }

    return {
        numero_factura: detectarNumeroFactura(plano),
        proveedor: detectarProveedor(lineas),
        rut_dni: detectarRut(plano),
        fecha_emision: detectarFecha(plano),
        moneda: detectarMoneda(plano),
        subtotal,
        iva,
        total,
        items,
        advertencia
    };
}

function detectarMoneda(plano) {
    return /\bUSD\b|U\$S|\bD[ÓO]LAR(?:ES)?\b/i.test(plano) ? "USD" : "UYU";
}

function detectarNumeroFactura(plano) {
    // e-Factura: "e-Factura" seguido de serie y número (A 1633)
    // (puede haber alguna línea intermedia, p. ej. "ORDEN DE COMPRA")
    let m = plano.match(
        /[eE]-?[fF]actura[\s\S]{0,60}?(?:^|\s)([A-Z]{1,3})[ \-]?(\d{2,10})(?=\s|$)/m
    );

    if (m) return `${m[1]}-${m[2]}`;

    m = plano.match(
        /(?:factura|e-?ticket|comprobante|n[°ºo]\.?|nro\.?|n[úu]mero)\s*[:#\-]?\s*([A-Z]{1,3}[\s\-]?\d{3,}(?:[\-\/]\d+)?|\d{3,}(?:[\-\/]\d+)?)/i
    );

    return m ? m[1].trim().replace(/\s+/g, "-").toUpperCase() : "";
}

function detectarRut(plano) {
    // e-Factura: el RUT del proveedor figura como "RUT EMISOR"
    let m = plano.match(/RUT\s*EMISOR\s*:?\s*(\d{12})/i);

    if (m) return m[1];

    m = plano.match(
        /(?:R\.?\s?U\.?\s?[TC]\.?|C\.?\s?U\.?\s?I\.?\s?[TL]\.?|C\.?\s?I\.?|DNI)\s*[:\-]?\s*(\d[\d.\-\s]{6,14}\d)/i
    );

    return m ? m[1].replace(/\D/g, "") : "";
}

function detectarFecha(plano) {
    let m = plano.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);

    if (m) return fechaValida(m[1], m[2], m[3]);

    m = plano.match(/\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4}|\d{2})\b/);

    if (m) {
        const anio = m[3].length === 2 ? `20${m[3]}` : m[3];
        return fechaValida(anio, m[2], m[1]);
    }

    return "";
}

function fechaValida(anio, mes, dia) {
    const a = Number(anio);
    const m = Number(mes);
    const d = Number(dia);

    if (m < 1 || m > 12 || d < 1 || d > 31 || a < 2000 || a > 2100) {
        return "";
    }

    return `${a}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

function detectarProveedor(lineas) {
    const razonSocial =
        /(^|\s)(S\.?\s?A\.?|S\.?\s?R\.?\s?L\.?|S\.?\s?A\.?\s?S\.?|LTDA\.?)(\s|$|,)/i;

    // El comprador (la propia empresa) nunca es el proveedor
    const comprador = /pronaos|portico|pórtico|comprador/i;

    const candidata = lineas
        .slice(0, 15)
        .find(l =>
            razonSocial.test(l) &&
            !comprador.test(l) &&
            l.length < 80
        );

    if (candidata) return candidata;

    const descartar =
        /factura|e-?ticket|rut|c\.?i\.?\b|fecha|tel|tel[eé]fono|www|@|cliente|comprobante|original|duplicado/i;

    const primera = lineas
        .slice(0, 6)
        .find(l =>
            (l.match(/[A-Za-zÁÉÍÓÚáéíóúÑñ]/g) || []).length >= 4 &&
            !descartar.test(l) &&
            !comprador.test(l) &&
            l.length < 80
        );

    return primera || "";
}

/* ---------- Detección del detalle ---------- */

const LETRAS = "A-Za-zÁÉÍÓÚáéíóúÑñ";
const NUM = "\\$?\\s*(\\d[\\d.,]*)";

const PATRONES_ITEM = [
    // cantidad  descripción  P.UNIT  DESC.  SUB.TOTAL   (e-Factura)
    {
        re: new RegExp(
            "^(\\d[\\d.,]*)\\s+(.*[" + LETRAS + "].*?)\\s+" +
            NUM + "\\s+" + NUM + "\\s+" + NUM + "$"
        ),
        orden: ["q", "desc", "p", "d", "s"]
    },
    // cantidad  descripción  precio  subtotal
    {
        re: new RegExp(
            "^(\\d[\\d.,]*)\\s+(.*[" + LETRAS + "].*?)\\s+" +
            NUM + "\\s+" + NUM + "$"
        ),
        orden: ["q", "desc", "p", "s"]
    },
    // descripción  cantidad  precio  subtotal
    {
        re: new RegExp(
            "^(.*[" + LETRAS + "].*?)\\s+" +
            NUM + "\\s+" + NUM + "\\s+" + NUM + "$"
        ),
        orden: ["desc", "q", "p", "s"]
    }
];

/* "7.500" puede ser 7,5 (punto decimal) o 7500 (miles): se prueban ambas */
function candidatosCantidad(texto) {
    const candidatos = [];

    if (/^\d+\.\d{1,3}$/.test(texto)) candidatos.push(Number(texto));

    candidatos.push(parseNumeroLocal(texto));

    return candidatos.filter(Number.isFinite);
}

/* Devuelve la tasa de IVA incluida en el subtotal de la línea, o null si
   cantidad × precio no cuadra con el subtotal (no es una línea de detalle) */
function validarItem(q, p, d, s) {
    const tolerancia = Math.max(1, Math.abs(s) * 0.02);
    const base = q * p - (d || 0);

    for (const tasa of [0.22, 0.10, 0]) {
        if (Math.abs(base * (1 + tasa) - s) <= tolerancia) return tasa;
    }

    return null;
}

function detectarItems(lineas) {
    const excluir =
        /\btotal\b|\biva\b|i\.v\.a|descuento|recargo|saldo|pagar|\bneto\b|\bcae\b/i;

    const items = [];

    lineas.forEach(linea => {
        if (excluir.test(linea)) return;

        for (const { re, orden } of PATRONES_ITEM) {
            const m = linea.match(re);

            if (!m) continue;

            const v = {};

            orden.forEach((clave, i) => {
                v[clave] = m[i + 1];
            });

            const p = parseNumeroLocal(v.p);
            const s = parseNumeroLocal(v.s);
            const d = v.d !== undefined ? parseNumeroLocal(v.d) : 0;

            if (![p, s, d].every(Number.isFinite)) continue;

            for (const q of candidatosCantidad(v.q)) {
                if (q <= 0) continue;

                const tasa = validarItem(q, p, d, s);

                if (tasa === null) continue;

                items.push({
                    descripcion: v.desc.replace(/[|_]+/g, " ").trim(),
                    cantidad: q,
                    precio_unitario: p,
                    subtotal_linea: s,
                    tasa_iva: tasa
                });

                return;
            }
        }
    });

    return items;
}

function buscarMonto(lineas, etiqueta, ignorarPorcentaje = false, excluir = null) {
    for (let i = lineas.length - 1; i >= 0; i--) {
        const linea = lineas[i];

        if (!etiqueta.test(linea)) continue;
        if (excluir && excluir.test(linea)) continue;

        const montos = extraerMontos(linea);

        if (montos.length) return montos[montos.length - 1];
    }

    return null;
}

function extraerMontos(linea) {
    const sinPorcentajes = linea.replace(/\d+(?:[.,]\d+)?\s*%/g, "");

    const coincidencias =
        sinPorcentajes.match(/\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?/g) || [];

    return coincidencias
        .map(parseNumeroLocal)
        .filter(n => Number.isFinite(n));
}

function parseNumeroLocal(valor) {
    let t = String(valor).replace(/[^\d.,]/g, "");

    if (t.includes(",")) {
        t = t.replace(/\./g, "").replace(",", ".");
    } else if (/^\d{1,3}(\.\d{3})+$/.test(t)) {
        t = t.replace(/\./g, "");
    }

    return Number(t);
}

function normalizarTexto(valor) {
    return String(valor || "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase();
}

function detectarObraEnTexto(texto) {
    const textoNorm = normalizarTexto(texto);
    const opciones = [...document.querySelectorAll("#idObra option")]
        .filter(o => o.value);

    for (const opcion of opciones) {
        const nombre = normalizarTexto(opcion.textContent)
            .trim()
            .replace(/^obra\s+/, "");

        if (nombre.length >= 4 && textoNorm.includes(nombre)) {
            return opcion.value;
        }
    }

    return null;
}

/* ---------- Volcado en el formulario ---------- */

function cargarResultadoOCR(data) {
    const resultado = {
        campos: 0,
        items: 0,
        proveedor: false,
        fecha: false,
        moneda: data && data.moneda ? data.moneda : "UYU"
    };

    if (!data) return resultado;

    const asignar = (id, valor) => {
        if (valor === null || valor === undefined || valor === "") {
            return false;
        }

        document.getElementById(id).value = valor;
        resultado.campos++;

        return true;
    };

    asignar("numeroFactura", data.numero_factura);
    resultado.proveedor = asignar("proveedor", data.proveedor);
    asignar("rutProveedor", data.rut_dni || data.rut);
    resultado.fecha = asignar(
        "fechaEmision",
        data.fecha_emision || data.fecha
    );

    establecerMoneda(resultado.moneda);

    let idObra = data.id_obra || null;
    let tipo = data.tipo_gasto || null;

    if (!idObra && data.texto_ocr) {
        idObra = detectarObraEnTexto(data.texto_ocr);
    }

    if (idObra && !tipo) tipo = "Obra";

    if (tipo) {
        const select = document.getElementById("tipoGasto");

        select.value = tipo;
        select.dispatchEvent(new Event("change"));
    }

    if (idObra) {
        document.getElementById("idObra").value = String(idObra);
    }

    if (Array.isArray(data.items) && data.items.length) {
        itemsFactura = [];

        data.items.forEach(item => {
            itemsFactura.push({
                descripcion: item.descripcion || "",
                cantidad: Number(item.cantidad) || 1,
                precio_unitario: Number(item.precio_unitario) || 0,
                subtotal: 0
            });
        });

        renderizarItems();
        resultado.items = itemsFactura.length;
    }

    if (data.iva !== null && data.iva !== undefined) {
        document.getElementById("ivaFactura").value =
            Number(data.iva) || 0;
        resultado.campos++;
    }

    actualizarTotales();

    resultado.advertencia = data.advertencia || "";

    return resultado;
}

/* ------------------------------------------------------------------ */
/* TIPO DE GASTO, MONEDA, ÍTEMS Y TOTALES DEL FORMULARIO               */
/* ------------------------------------------------------------------ */

function configurarTipoGasto() {
    const select = document.getElementById("tipoGasto");
    const obraField = document.getElementById("obraField");

    select.addEventListener("change", () => {
        const esObra = select.value === "Obra";

        obraField.classList.toggle("hidden", !esObra);

        if (!esObra) {
            document.getElementById("idObra").value = "";
        }
    });
}

/* Agrega al formulario los campos Moneda y Tipo de cambio (sin tocar el HTML) */
function configurarMoneda() {
    const grid = document.querySelector(".form-grid");

    if (!grid || document.getElementById("monedaFactura")) return;

    const campoMoneda = document.createElement("div");

    campoMoneda.className = "field";
    campoMoneda.innerHTML = `
        <label for="monedaFactura">Moneda</label>
        <select id="monedaFactura">
            <option value="UYU">Pesos uruguayos (UYU)</option>
            <option value="USD">Dólares (USD)</option>
        </select>
    `;

    const campoCambio = document.createElement("div");

    campoCambio.className = "field hidden";
    campoCambio.id = "tipoCambioField";
    campoCambio.innerHTML = `
        <label for="tipoCambio">Tipo de cambio (UYU por USD) *</label>
        <input type="number"
               id="tipoCambio"
               min="0"
               step="0.01"
               placeholder="Ej.: 40.50">
        <small id="equivalenteUYU"></small>
    `;

    grid.appendChild(campoMoneda);
    grid.appendChild(campoCambio);

    document.getElementById("monedaFactura")
        .addEventListener("change", () => {
            const esUSD = obtenerMoneda() === "USD";

            campoCambio.classList.toggle("hidden", !esUSD);

            if (esUSD && !obtenerTipoCambio()) {
                const recordado = leerTipoCambioRecordado();

                if (recordado) {
                    document.getElementById("tipoCambio").value = recordado;
                }
            }

            actualizarTotales();
        });

    document.getElementById("tipoCambio")
        .addEventListener("input", actualizarTotales);
}

function obtenerMoneda() {
    const select = document.getElementById("monedaFactura");

    return select && select.value === "USD" ? "USD" : "UYU";
}

function establecerMoneda(moneda) {
    const select = document.getElementById("monedaFactura");

    if (!select) return;

    select.value = moneda === "USD" ? "USD" : "UYU";
    select.dispatchEvent(new Event("change"));
}

function obtenerTipoCambio() {
    const input = document.getElementById("tipoCambio");

    return input ? Number(input.value) || 0 : 0;
}

function leerTipoCambioRecordado() {
    try {
        return window.localStorage.getItem(CLAVE_TIPO_CAMBIO) || "";
    } catch (error) {
        return "";
    }
}

function recordarTipoCambio(valor) {
    try {
        window.localStorage.setItem(CLAVE_TIPO_CAMBIO, String(valor));
    } catch (error) {
        /* sin almacenamiento disponible: se ignora */
    }
}

function configurarItems() {
    document.getElementById("btnAgregarItem").addEventListener("click", () => {
        agregarItem();
    });

    document.getElementById("detalleFactura").addEventListener("input", e => {
        if (
            e.target.classList.contains("item-description") ||
            e.target.classList.contains("item-quantity") ||
            e.target.classList.contains("item-price")
        ) {
            actualizarTotales();
        }
    });

    document.getElementById("detalleFactura").addEventListener("click", e => {
        const button = e.target.closest(".btn-remove-item");

        if (!button) return;

        actualizarItemsDesdeDOM();

        const row = button.closest("tr");
        const index = Number(row.dataset.index);

        itemsFactura.splice(index, 1);
        renderizarItems();
        actualizarTotales();
    });
}

function agregarItem(item = {}) {
    actualizarItemsDesdeDOM();

    itemsFactura.push({
        descripcion: item.descripcion || "",
        cantidad: Number(item.cantidad) || 1,
        precio_unitario: Number(item.precio_unitario) || 0,
        subtotal: Number(item.subtotal) || 0
    });

    renderizarItems();
    actualizarTotales();
}

function renderizarItems() {
    const tbody = document.getElementById("detalleFactura");
    const moneda = obtenerMoneda();

    if (itemsFactura.length === 0) {
        tbody.innerHTML = `
            <tr class="empty-detail">
                <td colspan="5">No hay ítems agregados.</td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = itemsFactura.map((item, index) => `
        <tr data-index="${index}">
            <td>
                <input
                    type="text"
                    class="item-description"
                    value="${escapeAttribute(item.descripcion)}"
                    placeholder="Descripción">
            </td>

            <td>
                <input
                    type="number"
                    class="item-quantity"
                    min="0"
                    step="0.01"
                    value="${item.cantidad}">
            </td>

            <td>
                <input
                    type="number"
                    class="item-price"
                    min="0"
                    step="0.01"
                    value="${item.precio_unitario}">
            </td>

            <td class="item-subtotal">
                ${formatearMoneda(item.cantidad * item.precio_unitario, moneda)}
            </td>

            <td>
                <button
                    type="button"
                    class="btn-remove-item"
                    title="Eliminar ítem">
                    <i class="fa-solid fa-trash"></i>
                </button>
            </td>
        </tr>
    `).join("");
}

function actualizarItemsDesdeDOM() {
    const rows = document.querySelectorAll("#detalleFactura tr[data-index]");
    const moneda = obtenerMoneda();

    rows.forEach(row => {
        const index = Number(row.dataset.index);

        if (!itemsFactura[index]) return;

        const descripcion =
            row.querySelector(".item-description").value.trim();

        const cantidad =
            Number(row.querySelector(".item-quantity").value) || 0;

        const precio =
            Number(row.querySelector(".item-price").value) || 0;

        itemsFactura[index] = {
            descripcion,
            cantidad,
            precio_unitario: precio,
            subtotal: cantidad * precio
        };

        const subtotalCell = row.querySelector(".item-subtotal");

        if (subtotalCell) {
            subtotalCell.textContent =
                formatearMoneda(cantidad * precio, moneda);
        }
    });
}

function configurarTotales() {
    document.getElementById("ivaFactura").addEventListener("input", () => {
        actualizarTotales();
    });
}

function actualizarTotales() {
    actualizarItemsDesdeDOM();

    const moneda = obtenerMoneda();

    const subtotal = itemsFactura.reduce(
        (total, item) =>
            total + Number(item.cantidad) * Number(item.precio_unitario),
        0
    );

    const iva =
        Number(document.getElementById("ivaFactura").value) || 0;

    document.getElementById("subtotalFactura").textContent =
        formatearMoneda(subtotal, moneda);

    document.getElementById("totalFactura").textContent =
        formatearMoneda(subtotal + iva, moneda);

    const equivalente = document.getElementById("equivalenteUYU");

    if (equivalente) {
        const tc = obtenerTipoCambio();

        equivalente.textContent =
            moneda === "USD" && tc > 0
                ? `Equivale a ${formatearMoneda((subtotal + iva) * tc, "UYU")}`
                : "";
    }
}

function configurarBotones() {
    document.getElementById("btnProcesarOCR")
        .addEventListener("click", procesarOCR);

    document.getElementById("btnGuardarFactura")
        .addEventListener("click", guardarFactura);

    document.getElementById("btnActualizar")
        .addEventListener("click", cargarFacturas);

    document.getElementById("btnFiltrar")
        .addEventListener("click", aplicarFiltros);

    document.getElementById("btnCalcularDistribucion")
        .addEventListener("click", calcularDistribucion);
}

function configurarFiltros() {
    document.getElementById("filtroProveedor")
        .addEventListener("input", aplicarFiltros);

    document.getElementById("filtroTipo")
        .addEventListener("change", aplicarFiltros);

    document.getElementById("filtroDesde")
        .addEventListener("change", aplicarFiltros);

    document.getElementById("filtroHasta")
        .addEventListener("change", aplicarFiltros);
}

/* ------------------------------------------------------------------ */
/* OBRAS                                                               */
/* ------------------------------------------------------------------ */

async function cargarObras() {
    if (modoDemo) {
        llenarObras(OBRAS_DEMO);
        return;
    }

    try {
        const data = await llamarAPI(`${API_URL}?accion=obras`);

        llenarObras(data.obras || []);

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

function llenarObras(obras) {
    const select = document.getElementById("idObra");

    select.innerHTML = `
        <option value="">Seleccionar obra...</option>

        ${obras.map(obra => `
            <option value="${obra.id_obra}">
                ${escapeHtml(obra.nombre)}
            </option>
        `).join("")}
    `;
}

function obtenerNombreObra(id) {
    if (!id) return null;

    const option = document.querySelector(
        `#idObra option[value="${CSS.escape(String(id))}"]`
    );

    return option ? option.textContent.trim() : null;
}

/* ------------------------------------------------------------------ */
/* GUARDAR                                                             */
/* ------------------------------------------------------------------ */

async function guardarFactura() {
    actualizarItemsDesdeDOM();
    actualizarTotales();

    const numero =
        document.getElementById("numeroFactura").value.trim();

    const proveedor =
        document.getElementById("proveedor").value.trim();

    const rut =
        document.getElementById("rutProveedor").value.trim();

    const fecha =
        document.getElementById("fechaEmision").value;

    const tipoGasto =
        document.getElementById("tipoGasto").value;

    const idObra =
        document.getElementById("idObra").value || null;

    const inputArchivo =
        document.getElementById("archivoFactura");

    if (!proveedor) {
        mostrarFeedback("Ingresá el proveedor de la factura.", "warning");
        return;
    }

    if (!fecha) {
        mostrarFeedback("Ingresá la fecha de emisión.", "warning");
        return;
    }

    if (tipoGasto === "Obra" && !idObra) {
        mostrarFeedback("Seleccioná la obra asociada.", "warning");
        return;
    }

    if (itemsFactura.length === 0) {
        mostrarFeedback("Agregá al menos un ítem.", "warning");
        return;
    }

    const moneda = obtenerMoneda();
    const tipoCambio = moneda === "USD" ? obtenerTipoCambio() : 1;

    if (moneda === "USD" && !(tipoCambio > 0)) {
        mostrarFeedback(
            "La factura está en dólares: ingresá el tipo de cambio.",
            "warning"
        );

        return;
    }

    // Todo se guarda en pesos: si la factura es en USD se convierte.
    const convertir = valor => redondear2(Number(valor) * tipoCambio);

    const itemsGuardar = itemsFactura.map(item => ({
        ...item,
        precio_unitario: convertir(item.precio_unitario),
        subtotal: convertir(
            Number(item.cantidad) * Number(item.precio_unitario)
        )
    }));

    const subtotalOriginal = itemsFactura.reduce(
        (sum, item) =>
            sum + Number(item.cantidad) * Number(item.precio_unitario),
        0
    );

    const ivaOriginal =
        Number(document.getElementById("ivaFactura").value) || 0;

    const subtotal = convertir(subtotalOriginal);
    const iva = convertir(ivaOriginal);
    const total = redondear2(subtotal + iva);

    const textoGuardar =
        moneda === "USD"
            ? `${ocrTexto}\n[Factura en USD convertida a UYU. Tipo de cambio: ${tipoCambio}]`.trim()
            : ocrTexto;

    const estado = ocrUsado ? "Pendiente" : "Verificada";

    const factura = {
        numero_factura: numero,
        proveedor,
        rut_dni: rut,
        fecha_emision: fecha,
        tipo_gasto: tipoGasto,
        id_obra: idObra,
        obra: obtenerNombreObra(idObra),
        subtotal,
        iva,
        total,
        items: itemsGuardar,
        texto_ocr: textoGuardar,
        estado
    };

    if (modoDemo) {
        factura.id_factura =
            facturas.length > 0
                ? Math.max(
                    ...facturas.map(f => Number(f.id_factura) || 0)
                ) + 1
                : 1;

        facturas.unshift(factura);

        if (moneda === "USD") recordarTipoCambio(tipoCambio);

        aplicarFiltros();
        limpiarFormulario();

        mostrarFeedback(
            "Factura guardada correctamente en modo demostración.",
            "success"
        );

        return;
    }

    const formData = new FormData();

    formData.append("numero_factura", numero);
    formData.append("proveedor", proveedor);
    formData.append("rut_dni", rut);
    formData.append("fecha_emision", fecha);
    formData.append("tipo_gasto", tipoGasto);
    formData.append("id_obra", idObra || "");
    formData.append("subtotal", subtotal);
    formData.append("iva", iva);
    formData.append("total", total);
    formData.append("estado", estado);
    formData.append("texto_ocr", textoGuardar);
    formData.append("items", JSON.stringify(itemsGuardar));

    if (inputArchivo.files.length) {
        formData.append("archivo", inputArchivo.files[0]);
    }

    mostrarFeedback("Guardando factura...", "info", 0);

    try {
        await llamarAPI(
            `${API_URL}?accion=guardar`,
            { method: "POST", body: formData }
        );

        if (moneda === "USD") recordarTipoCambio(tipoCambio);

        mostrarFeedback(
            moneda === "USD"
                ? `Factura guardada y convertida a pesos (${formatearMoneda(total, "UYU")}).`
                : "Factura guardada correctamente.",
            "success"
        );

        limpiarFormulario();
        cargarFacturas();

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

/* ------------------------------------------------------------------ */
/* LISTADO, RESUMEN Y FILTROS                                          */
/* ------------------------------------------------------------------ */

async function cargarFacturas() {
    if (modoDemo) {
        if (facturas.length === 0) {
            facturas = obtenerFacturasDemo();
        }

        aplicarFiltros();
        return;
    }

    try {
        const data = await llamarAPI(`${API_URL}?accion=listar`);

        facturas = Array.isArray(data.facturas) ? data.facturas : [];

        aplicarFiltros();

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

function obtenerFacturasDemo() {
    return [
        {
            id_factura: 1,
            numero_factura: "A-000123",
            proveedor: "Proveedor de Materiales Rivera",
            rut_dni: "123456780012",
            fecha_emision: "2026-09-20",
            tipo_gasto: "Obra",
            id_obra: 1,
            obra: "Obra Rivera Centro",
            subtotal: 6500,
            iva: 1430,
            total: 7930,
            estado: "Verificada"
        },
        {
            id_factura: 2,
            numero_factura: "B-000458",
            proveedor: "Oficina Central SRL",
            rut_dni: "214567890019",
            fecha_emision: "2026-09-18",
            tipo_gasto: "General",
            id_obra: null,
            obra: null,
            subtotal: 12000,
            iva: 2640,
            total: 14640,
            estado: "Verificada"
        },
        {
            id_factura: 3,
            numero_factura: "A-000089",
            proveedor: "Ferretería del Norte",
            rut_dni: "217654320014",
            fecha_emision: "2026-09-15",
            tipo_gasto: "Obra",
            id_obra: 2,
            obra: "Obra Barrio Mandubí",
            subtotal: 8400,
            iva: 1848,
            total: 10248,
            estado: "Verificada"
        }
    ];
}

/*
 * Los filtros solo afectan a la tabla. El resumen siempre suma TODAS las
 * facturas vigentes (cualquier tipo de gasto), para no perder datos.
 */
function aplicarFiltros() {
    const proveedor =
        document.getElementById("filtroProveedor")
            .value.trim().toLowerCase();

    const tipo = document.getElementById("filtroTipo").value;
    const desde = document.getElementById("filtroDesde").value;
    const hasta = document.getElementById("filtroHasta").value;

    const filtradas = facturas.filter(factura => {
        const coincideProveedor =
            !proveedor ||
            String(factura.proveedor || "")
                .toLowerCase()
                .includes(proveedor);

        const coincideTipo = !tipo || factura.tipo_gasto === tipo;
        const coincideDesde = !desde || factura.fecha_emision >= desde;
        const coincideHasta = !hasta || factura.fecha_emision <= hasta;

        return (
            coincideProveedor &&
            coincideTipo &&
            coincideDesde &&
            coincideHasta
        );
    });

    actualizarResumen(facturas);
    renderizarFacturas(filtradas);
}

function renderizarFacturas(lista) {
    const tbody = document.getElementById("tablaFacturas");

    if (!lista.length) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" class="no-data">
                    No se encontraron facturas.
                </td>
            </tr>
        `;

        return;
    }

    tbody.innerHTML = lista.map(factura => {
        const estado = factura.estado || "Pendiente";
        const tipo = factura.tipo_gasto || "General";
        const anulada = estado === "Anulada";
        const puedeCambiar = estado === "Pendiente" || estado === "Verificada";
        const siguiente = estado === "Pendiente" ? "Verificada" : "Pendiente";

        return `
        <tr>
            <td>${formatearFecha(factura.fecha_emision)}</td>

            <td>${escapeHtml(factura.numero_factura || "-")}</td>

            <td>${escapeHtml(factura.proveedor || "-")}</td>

            <td>
                <span class="type-badge type-${escapeAttribute(tipo.toLowerCase())}">
                    ${escapeHtml(tipo)}
                </span>
            </td>

            <td>${escapeHtml(factura.obra || "Gasto general")}</td>

            <td><strong>${formatearMoneda(factura.total)}</strong></td>

            <td>
                <span class="status-badge status-${escapeAttribute(estado.toLowerCase())}">
                    ${escapeHtml(estado)}
                </span>
            </td>

            <td>
                ${puedeCambiar ? `
                <button
                    type="button"
                    class="action-btn action-status"
                    title="${estado === "Pendiente" ? "Marcar como verificada" : "Volver a pendiente"}"
                    onclick="cambiarEstadoFactura(${Number(factura.id_factura)}, '${siguiente}')">
                    <i class="fa-solid ${estado === "Pendiente" ? "fa-circle-check" : "fa-rotate-left"}"></i>
                </button>
                ` : ""}

                <button
                    type="button"
                    class="action-btn action-view"
                    title="Ver factura"
                    onclick="verFactura(${Number(factura.id_factura)})">
                    <i class="fa-solid fa-eye"></i>
                </button>

                <button
                    type="button"
                    class="action-btn action-delete"
                    title="Anular factura"
                    ${anulada ? "disabled style=\"opacity:.4;cursor:not-allowed\"" : ""}
                    onclick="anularFactura(${Number(factura.id_factura)})">
                    <i class="fa-solid fa-ban"></i>
                </button>
            </td>
        </tr>
    `;
    }).join("");
}

function actualizarResumen(lista) {
    const vigentes = lista.filter(f => f.estado !== "Anulada");

    const sumar = filtro =>
        vigentes
            .filter(filtro)
            .reduce((sum, f) => sum + Number(f.total || 0), 0);

    const gastoObra = sumar(f => f.tipo_gasto === "Obra");
    const gastoGeneral = sumar(f => f.tipo_gasto === "General");
    const total = sumar(() => true);

    document.getElementById("totalCantidadFacturas").textContent =
        vigentes.length;

    document.getElementById("totalGastosObra").textContent =
        formatearMoneda(gastoObra);

    document.getElementById("totalGastosGenerales").textContent =
        formatearMoneda(gastoGeneral);

    document.getElementById("totalGastos").textContent =
        formatearMoneda(total);
}

/* ------------------------------------------------------------------ */
/* COBERTURA DE GASTOS                                                 */
/* ------------------------------------------------------------------ */

async function calcularDistribucion() {
    const periodo =
        document.getElementById("periodoDistribucion").value;

    const criterio =
        document.getElementById("criterioDistribucion").value;

    if (!periodo) {
        mostrarFeedback(
            "Seleccioná el período que querés procesar.",
            "warning"
        );

        return;
    }

    if (modoDemo) {
        renderizarDistribucion(generarDistribucionDemo(periodo, criterio));

        mostrarFeedback(
            "Distribución calculada en modo demostración.",
            "success"
        );

        return;
    }

    try {
        const data = await llamarAPI(
            `${API_URL}?accion=distribuir`,
            {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ periodo, criterio })
            }
        );

        renderizarDistribucion(data);

        if (data.advertencia) {
            mostrarFeedback(data.advertencia, "warning", 8000);
        }

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

/*
 * Se cubren TODOS los gastos cargados en el período (facturas vigentes de
 * cualquier tipo). Cada obra debe cubrir:
 *   - sus gastos directos (facturas de tipo Obra asociadas a ella), más
 *   - su parte del resto de los gastos, según el criterio elegido.
 * Una factura de obra sin obra válida se prorratea, así no queda nada afuera.
 */
function generarDistribucionDemo(periodo, criterio) {
    const delPeriodo = facturas.filter(f =>
        f.estado !== "Anulada" &&
        String(f.fecha_emision || "").startsWith(periodo)
    );

    const idsObras = OBRAS_DEMO.map(o => o.id_obra);

    const esDirecto = f =>
        f.tipo_gasto === "Obra" && idsObras.includes(Number(f.id_obra));

    const totalGeneral = delPeriodo
        .filter(f => !esDirecto(f))
        .reduce((sum, f) => sum + Number(f.total || 0), 0);

    const basesDemo = {
        Por_Horas: [500, 300, 200],
        Por_Obreros: [12, 8, 5],
        Por_Porcentaje: [50, 30, 20]
    };

    const bases = basesDemo[criterio] || basesDemo.Por_Horas;

    const baseTotal = bases.reduce((sum, b) => sum + b, 0);
    const tasa = baseTotal ? totalGeneral / baseTotal : 0;

    const distribucion = OBRAS_DEMO.map((obra, i) => {
        const gastoDirecto = delPeriodo
            .filter(f =>
                esDirecto(f) &&
                Number(f.id_obra) === obra.id_obra
            )
            .reduce((sum, f) => sum + Number(f.total || 0), 0);

        const montoAsignado = bases[i] * tasa;

        return {
            id_obra: obra.id_obra,
            obra: obra.nombre,
            base: bases[i],
            porcentaje: baseTotal ? (bases[i] / baseTotal) * 100 : 0,
            tasa,
            gasto_directo: gastoDirecto,
            monto_asignado: montoAsignado,
            total_cubrir: gastoDirecto + montoAsignado
        };
    });

    const totalDirecto = distribucion.reduce(
        (sum, o) => sum + o.gasto_directo, 0
    );

    return {
        periodo,
        criterio,
        total_general: totalGeneral,
        total_directo: totalDirecto,
        total_operacion: totalGeneral + totalDirecto,
        base_total: baseTotal,
        tasa,
        distribucion
    };
}

function renderizarDistribucion(data) {
    const container = document.getElementById("resultadoDistribucion");

    const nombreCriterio = {
        Por_Horas: "Por horas-hombre",
        Por_Obreros: "Por obreros asignados",
        Por_Porcentaje: "Por porcentaje fijo"
    };

    const filas = (data.distribucion || []).map(item => {
        const directo = Number(item.gasto_directo) || 0;
        const asignado = Number(item.monto_asignado) || 0;
        const totalCubrir =
            item.total_cubrir !== undefined
                ? Number(item.total_cubrir)
                : directo + asignado;

        return { ...item, directo, asignado, totalCubrir };
    });

    const totalGeneral = Number(data.total_general) || 0;

    const totalDirecto =
        data.total_directo !== undefined
            ? Number(data.total_directo)
            : filas.reduce((sum, f) => sum + f.directo, 0);

    const totalOperacion =
        data.total_operacion !== undefined
            ? Number(data.total_operacion)
            : totalGeneral + totalDirecto;

    const criterio = nombreCriterio[data.criterio] || data.criterio;

    container.innerHTML = `
        <div class="distribution-summary">

            <div class="distribution-summary-card">
                <span>Total de gastos cargados en el período</span>
                <strong>${formatearMoneda(totalOperacion)}</strong>
            </div>

            <div class="distribution-summary-card">
                <span>Asignados directamente a cada obra</span>
                <strong>${formatearMoneda(totalDirecto)}</strong>
            </div>

            <div class="distribution-summary-card">
                <span>Prorrateados entre las obras</span>
                <strong>${formatearMoneda(totalGeneral)}</strong>
            </div>

        </div>

        <div class="distribution-table-wrapper">

            <table class="distribution-table">

                <thead>
                    <tr>
                        <th>Obra</th>
                        <th>Base (${escapeHtml(criterio)})</th>
                        <th>Participación</th>
                        <th>Gasto directo</th>
                        <th>Parte prorrateada</th>
                        <th>Total a cubrir</th>
                    </tr>
                </thead>

                <tbody>

                    ${filas.map(item => `
                        <tr>
                            <td>${escapeHtml(item.obra)}</td>
                            <td>${formatearNumero(item.base)}</td>
                            <td>${Number(item.porcentaje).toFixed(2)}%</td>
                            <td>${formatearMoneda(item.directo)}</td>
                            <td>${formatearMoneda(item.asignado)}</td>
                            <td><strong>${formatearMoneda(item.totalCubrir)}</strong></td>
                        </tr>
                    `).join("")}

                    <tr>
                        <td>TOTAL</td>
                        <td>${formatearNumero(data.base_total)}</td>
                        <td>100%</td>
                        <td>${formatearMoneda(totalDirecto)}</td>
                        <td>${formatearMoneda(totalGeneral)}</td>
                        <td>${formatearMoneda(totalOperacion)}</td>
                    </tr>

                </tbody>

            </table>

        </div>
    `;
}

/* ------------------------------------------------------------------ */
/* ACCIONES DE LA TABLA                                                */
/* ------------------------------------------------------------------ */

function verFactura(id) {
    const factura = facturas.find(
        f => Number(f.id_factura) === Number(id)
    );

    if (!factura) return;

    if (modoDemo || !factura.nombre_archivo) {
        mostrarFeedback(
            "Esta factura no tiene un archivo adjunto para mostrar.",
            "warning"
        );

        return;
    }

    abrirVisorFactura(factura);
}

/* ---------- Visor del archivo original (imagen o PDF) ---------- */

function crearVisorFactura() {
    if (document.getElementById("visorFactura")) return;

    const estilos = document.createElement("style");

    estilos.textContent = `
        #visorFactura {
            position: fixed;
            inset: 0;
            z-index: 9999;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            background: rgba(15, 23, 42, 0.7);
        }
        #visorFactura.hidden { display: none; }
        #visorFactura .visor-ventana {
            display: flex;
            flex-direction: column;
            width: min(960px, 100%);
            height: min(90vh, 100%);
            background: #ffffff;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
        }
        #visorFactura .visor-barra {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            padding: 12px 16px;
            border-bottom: 1px solid #e2e8f0;
        }
        #visorFactura .visor-titulo {
            font-weight: 600;
            font-size: 14px;
            color: #1e293b;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        #visorFactura .visor-acciones {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-shrink: 0;
        }
        #visorFactura .visor-acciones a,
        #visorFactura .visor-acciones button {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            font-size: 13px;
            color: #334155;
            background: #ffffff;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            cursor: pointer;
            text-decoration: none;
        }
        #visorFactura .visor-cuerpo {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: auto;
            background: #f1f5f9;
        }
        #visorFactura iframe {
            width: 100%;
            height: 100%;
            border: 0;
        }
        #visorFactura img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
        }
        #visorFactura .visor-error {
            padding: 24px;
            color: #b54747;
            font-size: 14px;
        }
    `;

    document.head.appendChild(estilos);

    const visor = document.createElement("div");

    visor.id = "visorFactura";
    visor.className = "hidden";
    visor.setAttribute("role", "dialog");
    visor.setAttribute("aria-modal", "true");

    visor.innerHTML = `
        <div class="visor-ventana">
            <div class="visor-barra">
                <span class="visor-titulo" id="visorFacturaTitulo"></span>

                <div class="visor-acciones">
                    <a id="visorFacturaAbrir" target="_blank" rel="noopener">
                        <i class="fa-solid fa-up-right-from-square"></i>
                        Abrir en pestaña nueva
                    </a>

                    <button type="button" id="visorFacturaCerrar">
                        <i class="fa-solid fa-xmark"></i>
                        Cerrar
                    </button>
                </div>
            </div>

            <div class="visor-cuerpo" id="visorFacturaCuerpo"></div>
        </div>
    `;

    document.body.appendChild(visor);

    document.getElementById("visorFacturaCerrar")
        .addEventListener("click", cerrarVisorFactura);

    visor.addEventListener("click", e => {
        if (e.target === visor) cerrarVisorFactura();
    });

    document.addEventListener("keydown", e => {
        if (e.key === "Escape") cerrarVisorFactura();
    });
}

function abrirVisorFactura(factura) {
    crearVisorFactura();

    const url =
        `${API_URL}?accion=archivo&id=${encodeURIComponent(factura.id_factura)}`;

    const esPDF =
        factura.tipo_archivo === "application/pdf" ||
        /\.pdf$/i.test(factura.nombre_archivo || "");

    const titulo =
        `Factura ${factura.numero_factura || factura.id_factura} — ${factura.proveedor || ""}`;

    document.getElementById("visorFacturaTitulo").textContent = titulo;
    document.getElementById("visorFacturaAbrir").href = url;

    const cuerpo = document.getElementById("visorFacturaCuerpo");

    cuerpo.innerHTML = "";

    if (esPDF) {
        const marco = document.createElement("iframe");

        marco.src = url;
        marco.title = titulo;

        cuerpo.appendChild(marco);
    } else {
        const imagen = document.createElement("img");

        imagen.alt = titulo;

        imagen.addEventListener("error", () => {
            cuerpo.innerHTML =
                '<div class="visor-error">No se pudo cargar el archivo de la factura.</div>';
        });

        imagen.src = url;

        cuerpo.appendChild(imagen);
    }

    document.getElementById("visorFactura").classList.remove("hidden");
}

function cerrarVisorFactura() {
    const visor = document.getElementById("visorFactura");

    if (!visor || visor.classList.contains("hidden")) return;

    visor.classList.add("hidden");
    document.getElementById("visorFacturaCuerpo").innerHTML = "";
}

async function cambiarEstadoFactura(id, nuevoEstado) {
    const factura = facturas.find(
        f => Number(f.id_factura) === Number(id)
    );

    if (!factura || factura.estado === "Anulada") return;

    if (!modoDemo) {
        try {
            await llamarAPI(
                `${API_URL}?accion=estado`,
                {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        id_factura: factura.id_factura,
                        estado: nuevoEstado
                    })
                }
            );
        } catch (error) {
            mostrarFeedback(error.message, "error");
            return;
        }
    }

    factura.estado = nuevoEstado;

    aplicarFiltros();

    mostrarFeedback(
        `Factura ${factura.numero_factura || id} marcada como ${nuevoEstado.toLowerCase()}.`,
        "success"
    );
}

async function anularFactura(id) {
    const factura = facturas.find(
        f => Number(f.id_factura) === Number(id)
    );

    if (!factura) return;

    const confirmar = window.confirm(
        `¿Deseás anular la factura ${factura.numero_factura || id}?`
    );

    if (!confirmar) return;

    if (modoDemo) {
        factura.estado = "Anulada";

        aplicarFiltros();

        mostrarFeedback(
            "Factura anulada en modo demostración.",
            "success"
        );

        return;
    }

    try {
        await llamarAPI(
            `${API_URL}?accion=anular`,
            {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ id_factura: factura.id_factura })
            }
        );

        factura.estado = "Anulada";

        aplicarFiltros();

        mostrarFeedback("Factura anulada.", "success");

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

function limpiarFormulario() {
    document.getElementById("numeroFactura").value = "";
    document.getElementById("proveedor").value = "";
    document.getElementById("rutProveedor").value = "";
    document.getElementById("fechaEmision").value = hoyLocal();

    document.getElementById("tipoGasto").value = "General";
    document.getElementById("tipoGasto").dispatchEvent(new Event("change"));

    document.getElementById("ivaFactura").value = "0";
    document.getElementById("archivoFactura").value = "";

    establecerMoneda("UYU");

    const fileBox = document.getElementById("archivoSeleccionado");

    fileBox.classList.add("hidden");
    fileBox.textContent = "";

    ocrUsado = false;
    ocrTexto = "";

    itemsFactura = [];

    agregarItem();
}

/* ------------------------------------------------------------------ */
/* UTILIDADES                                                          */
/* ------------------------------------------------------------------ */

/* duracion en ms; 0 = el mensaje queda hasta el siguiente */
function mostrarFeedback(mensaje, tipo = "info", duracion = 5000) {
    const feedback = document.getElementById("feedback");

    const icono =
        tipo === "success" ? "fa-circle-check"
            : tipo === "error" ? "fa-circle-xmark"
                : tipo === "warning" ? "fa-triangle-exclamation"
                    : "fa-circle-info";

    feedback.className = `feedback-msg ${tipo}`;

    feedback.innerHTML = `
        <i class="fa-solid ${icono}"></i>
        <span>${escapeHtml(mensaje)}</span>
    `;

    window.clearTimeout(mostrarFeedback.timeout);

    if (duracion > 0) {
        mostrarFeedback.timeout = window.setTimeout(() => {
            feedback.classList.add("hidden");
        }, duracion);
    }
}

/* Obtiene (y guarda) el token CSRF que exige el servidor en los POST */
async function obtenerCsrf() {
    if (csrfToken) return csrfToken;

    const data = await llamarAPI(`${API_BASE}/csrf.php`);

    csrfToken = data.token || "";

    return csrfToken;
}

/* Llama a la API y devuelve el JSON; lanza Error con un mensaje legible si falla */
async function llamarAPI(url, opciones = {}) {
    const metodo = String(opciones.method || "GET").toUpperCase();
    const headers = { ...(opciones.headers || {}) };

    if (metodo !== "GET") {
        headers["X-CSRF-Token"] = await obtenerCsrf();
    }

    let response;

    try {
        response = await fetch(url, {
            credentials: "include",
            ...opciones,
            headers
        });
    } catch (error) {
        throw new Error("No se pudo conectar con el servidor.");
    }

    const texto = await response.text();
    let data;

    try {
        data = JSON.parse(texto);
    } catch (error) {
        throw new Error(
            response.status === 404
                ? "No se encontró el archivo de la API en el servidor (" + url + ")."
                : "El servidor devolvió una respuesta inválida (revisá el log de errores de PHP)."
        );
    }

    if (!response.ok || data.success === false) {
        if (response.status === 403) {
            csrfToken = "";
        }

        throw new Error(
            data.error || data.mensaje || "La operación no pudo completarse."
        );
    }

    return data;
}

function formatearMoneda(valor, moneda = "UYU") {
    return new Intl.NumberFormat("es-UY", {
        style: "currency",
        currency: moneda === "USD" ? "USD" : "UYU",
        minimumFractionDigits: 2
    }).format(Number(valor) || 0);
}

function formatearNumero(valor) {
    return new Intl.NumberFormat("es-UY", {
        minimumFractionDigits: 0,
        maximumFractionDigits: 2
    }).format(Number(valor) || 0);
}

function formatearFecha(fecha) {
    if (!fecha) return "-";

    const partes = String(fecha).split("-");

    if (partes.length !== 3) return fecha;

    return `${partes[2]}/${partes[1]}/${partes[0]}`;
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function escapeAttribute(value) {
    return escapeHtml(value);
}

/* ------------------------------------------------------------------ */
/* PORCENTAJE FIJO POR OBRA (criterio Por_Porcentaje)                  */
/* ------------------------------------------------------------------ */

function configurarPorcentajes() {
    const controles = document.querySelector(".distribution-controls");
    const criterio = document.getElementById("criterioDistribucion");

    if (!controles || !criterio || document.getElementById("panelPorcentajes")) {
        return;
    }

    const panel = document.createElement("div");

    panel.id = "panelPorcentajes";
    panel.className = "hidden";
    panel.innerHTML = `
        <p style="margin:12px 0 8px;font-size:14px">
            Porcentaje de los gastos generales que absorbe cada obra activa.
            Deben sumar 100%.
        </p>
        <div id="listaPorcentajes"
             style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px"></div>
        <div style="display:flex;align-items:center;gap:12px;margin-top:10px">
            <strong id="sumaPorcentajes">Total: 0%</strong>
            <button type="button" id="btnGuardarPorcentajes" class="btn-secondary">
                <i class="fa-solid fa-floppy-disk"></i>
                Guardar porcentajes
            </button>
        </div>
    `;

    controles.insertAdjacentElement("afterend", panel);

    criterio.addEventListener("change", actualizarPanelPorcentajes);

    panel.addEventListener("input", e => {
        if (e.target.classList.contains("pct-obra")) {
            actualizarSumaPorcentajes();
        }
    });

    document.getElementById("btnGuardarPorcentajes")
        .addEventListener("click", guardarPorcentajes);

    actualizarPanelPorcentajes();
}

async function actualizarPanelPorcentajes() {
    const panel = document.getElementById("panelPorcentajes");
    const esPorcentaje =
        document.getElementById("criterioDistribucion").value === "Por_Porcentaje";

    panel.classList.toggle("hidden", !esPorcentaje || modoDemo);

    if (!esPorcentaje || modoDemo) return;

    try {
        const data = await llamarAPI(`${API_URL}?accion=porcentajes`);

        document.getElementById("listaPorcentajes").innerHTML =
            (data.obras || []).map(obra => `
                <div class="field">
                    <label>${escapeHtml(obra.nombre)}</label>
                    <input type="number"
                           class="pct-obra"
                           data-id="${Number(obra.id_obra)}"
                           min="0"
                           max="100"
                           step="0.01"
                           value="${Number(obra.porcentaje) || 0}">
                </div>
            `).join("");

        actualizarSumaPorcentajes();

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}

function actualizarSumaPorcentajes() {
    const suma = [...document.querySelectorAll(".pct-obra")]
        .reduce((total, input) => total + (Number(input.value) || 0), 0);

    const etiqueta = document.getElementById("sumaPorcentajes");
    const correcto = Math.abs(suma - 100) <= 0.01;

    etiqueta.textContent = `Total: ${formatearNumero(suma)}%`;
    etiqueta.style.color = correcto ? "#15803d" : "#b54747";
}

async function guardarPorcentajes() {
    const porcentajes = [...document.querySelectorAll(".pct-obra")].map(input => ({
        id_obra: Number(input.dataset.id),
        porcentaje: Number(input.value) || 0
    }));

    if (!porcentajes.length) {
        mostrarFeedback("No hay obras activas para configurar.", "warning");
        return;
    }

    try {
        await llamarAPI(
            `${API_URL}?accion=guardar_porcentajes`,
            {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ porcentajes })
            }
        );

        mostrarFeedback("Porcentajes guardados.", "success");

    } catch (error) {
        mostrarFeedback(error.message, "error");
    }
}