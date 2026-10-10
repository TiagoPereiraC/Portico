document.addEventListener("DOMContentLoaded", () => {
    inicializarFecha();
    inicializarColapsableAnaliticas();
    cargarMetricasDashboard();
});

function sendDesktopRequest(type, payload, responseType) {
    return new Promise((resolve, reject) => {
        if (!window.chrome?.webview) {
            reject(new Error("No se detectó el entorno de escritorio."));
            return;
        }

        const requestId = `${type}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
        const timer = setTimeout(() => {
            window.chrome.webview.removeEventListener("message", onMessage);
            reject(new Error("Tiempo de espera agotado."));
        }, 12000);

        function onMessage(event) {
            let data = event.data;
            if (typeof data === "string") {
                try {
                    data = JSON.parse(data);
                } catch {
                    return;
                }
            }
            if (!data || data.requestId !== requestId) return;

            window.chrome.webview.removeEventListener("message", onMessage);
            clearTimeout(timer);

            if (data.success) {
                resolve(data);
            } else {
                reject(new Error(data.error || "Error al procesar la solicitud."));
            }
        }

        window.chrome.webview.addEventListener("message", onMessage);
        window.chrome.webview.postMessage(JSON.stringify({ type, requestId, ...payload }));
    });
}

// Misma resolución de ruta que obreros.js: la API está en /api, un nivel
// por encima de /web-ui/
function resolveApiBase() {
    const path = window.location.pathname;
    const idx = path.lastIndexOf("/web-ui/");

    if (idx !== -1) {
        return window.location.origin + path.substring(0, idx) + "/api";
    }

    return window.location.origin + "/api";
}

const API_BASE = resolveApiBase();

let resizeTimer = null;
window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(redimensionarGraficos, 150);
});

document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
        setTimeout(redimensionarGraficos, 100);
    }
});

function redimensionarGraficos() {
    const content = document.getElementById("analyticsContent");
    if (!content || content.style.display === "none") return;

    if (chartCargosInstance) {
        const isWide = window.innerWidth >= 1400;
        if (chartCargosInstance.options.plugins?.legend) {
            chartCargosInstance.options.plugins.legend.position = isWide ? "right" : "bottom";
        }
        chartCargosInstance.resize();
    }
    if (chartHorasInstance) {
        chartHorasInstance.resize();
    }
}


function inicializarColapsableAnaliticas() {
    const btn = document.getElementById("btnToggleAnalytics");
    const content = document.getElementById("analyticsContent");
    const text = document.getElementById("toggleAnalyticsText");
    const chevron = document.getElementById("toggleAnalyticsChevron");

    if (!btn || !content) return;

    btn.addEventListener("click", () => {
        const estaOculto = content.style.display === "none" || content.style.display === "";
        if (estaOculto) {
            content.style.display = "block";
            if (text) text.textContent = "Ocultar gráficos";
            if (chevron) chevron.classList.add("is-rotated");
            btn.setAttribute("aria-expanded", "true");

            requestAnimationFrame(() => {
                redimensionarGraficos();
            });
        } else {
            content.style.display = "none";
            if (text) text.textContent = "Desplegar gráficos";
            if (chevron) chevron.classList.remove("is-rotated");
            btn.setAttribute("aria-expanded", "false");
        }
    });
}


// Paleta ejecutiva moderna para gráficos (libre de saturación en rojo)
const COLORES_PORTICO = [
    "#3b82f6", // Azul profesional
    "#10b981", // Verde esmeralda
    "#f59e0b", // Ámbar suave
    "#6366f1", // Índigo
    "#0d9488", // Turquesa / cerceta
    "#8b5cf6", // Violeta suave
    "#64748b", // Pizarra
    "#ec4899", // Rosa suave
    "#06b6d4", // Cyan
    "#84cc16"  // Lima suave
];

let chartCargosInstance = null;
let chartHorasInstance = null;

function inicializarFecha() {
    const el = document.getElementById("currentDateDisplay");
    if (!el) return;

    const ahora = new Date();
    const opciones = {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric"
    };
    const fechaTexto = ahora.toLocaleDateString("es-AR", opciones);
    el.textContent = fechaTexto.charAt(0).toUpperCase() + fechaTexto.slice(1);
}

async function cargarMetricasDashboard() {
    try {
        let datos;

        if (window.chrome && window.chrome.webview) {
            datos = await sendDesktopRequest("dashboard_metricas", {}, "dashboard_metricas_response");
        } else {
            const res = await fetch(`${API_BASE}/dashboard.php`, { credentials: "include" });
            if (!res.ok) throw new Error("Error al obtener métricas del servidor.");
            datos = await res.json();
        }

        if (datos && datos.data) {
            renderizarKPIs(datos.data.kpis);
            renderizarResumenOperativo(datos.data.kpis);
            renderizarGraficoCargos(datos.data.distribucion_cargos || []);
            renderizarGraficoHoras(datos.data.horas_por_obra || []);
        }
    } catch (error) {
        console.error("Error cargando dashboard:", error);
    }
}

function animarNumero(elementoId, valorFinal, esDecimal = false, prefijo = "", sufijo = "") {
    const el = document.getElementById(elementoId);
    if (!el) return;

    const num = Number(valorFinal) || 0;
    const inicio = 0;
    const duracion = 800;
    const pasos = 25;
    const incremento = num / pasos;
    let actual = inicio;
    let contador = 0;

    const timer = setInterval(() => {
        contador++;
        actual += incremento;
        if (contador >= pasos) {
            clearInterval(timer);
            const formatted = esDecimal
                ? num.toLocaleString("es-AR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })
                : num.toLocaleString("es-AR");
            el.textContent = `${prefijo}${formatted}${sufijo}`;
        } else {
            const formatted = esDecimal
                ? actual.toLocaleString("es-AR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })
                : Math.round(actual).toLocaleString("es-AR");
            el.textContent = `${prefijo}${formatted}${sufijo}`;
        }
    }, duracion / pasos);
}

function renderizarKPIs(kpis) {
    if (!kpis) return;

    // 1. Obras
    const activasObras = kpis.obras?.activas ?? 0;
    const totalObras = kpis.obras?.total ?? 0;
    animarNumero("kpiObrasActivas", activasObras);
    const elObrasTotal = document.getElementById("kpiObrasTotal");
    if (elObrasTotal) elObrasTotal.textContent = `${totalObras} en total`;

    const avancePct = kpis.actividades?.porcentaje_avance ?? 0;
    const elObrasAvance = document.getElementById("kpiObrasAvance");
    if (elObrasAvance) {
        elObrasAvance.textContent = avancePct > 0 
            ? `Avance actividades: ${avancePct}%`
            : "Proyectos en ejecución";
    }

    // 2. Obreros
    const activosObreros = kpis.obreros?.activos ?? 0;
    const totalObreros = kpis.obreros?.total ?? 0;
    animarNumero("kpiObrerosActivos", activosObreros);
    const elObrerosTotal = document.getElementById("kpiObrerosTotal");
    if (elObrerosTotal) elObrerosTotal.textContent = `${totalObreros} registrados`;

    const contratosPorVencer = kpis.alertas?.contratos ?? 0;
    const elObrerosHint = document.getElementById("kpiObrerosAlertasHint");
    if (elObrerosHint) {
        elObrerosHint.textContent = contratosPorVencer > 0
            ? `${contratosPorVencer} contrato${contratosPorVencer === 1 ? '' : 's'} por vencer`
            : "Cuadrillas operativas al día";
    }

    // 3. Maquinaria
    const totalMaq = kpis.maquinaria?.total ?? 0;
    const asignadaMaq = kpis.maquinaria?.asignada ?? 0;
    const alertasCert = kpis.alertas?.certificados ?? 0;
    animarNumero("kpiMaquinariaTotal", totalMaq);

    const elMaqAlertas = document.getElementById("kpiMaqAlertas");
    if (elMaqAlertas) {
        elMaqAlertas.textContent = `${alertasCert} alerta${alertasCert === 1 ? '' : 's'}`;
        if (alertasCert > 0) {
            elMaqAlertas.className = "kpi-badge badge-warning";
        } else {
            elMaqAlertas.className = "kpi-badge badge-success";
            elMaqAlertas.textContent = "Al día";
        }
    }

    const elMaqAsignada = document.getElementById("kpiMaqAsignada");
    if (elMaqAsignada) elMaqAsignada.textContent = `${asignadaMaq} de ${totalMaq} equipos operando`;

    // 4. Horas y Asistencia
    const totalHoras = kpis.horas?.total_horas ?? 0;
    const totalRegistros = kpis.horas?.total_registros ?? 0;
    animarNumero("subKpiHoras", totalHoras, true, "", " hrs");

    const elRegistros = document.getElementById("subKpiRegistros");
    if (elRegistros) elRegistros.textContent = `${totalRegistros} partes`;
}

function renderizarResumenOperativo(kpis) {
    if (!kpis) return;

    // 1. Avance de Actividades de Contrato
    const pctAvance = kpis.actividades?.porcentaje_avance ?? 0;
    animarNumero("subKpiAvanceContratos", pctAvance, true, "", "%");

    // 2. Control de Combustible
    const litrosComb = kpis.combustible?.total_litros ?? 0;
    animarNumero("kpiCombustibleLitros", litrosComb, litrosComb % 1 !== 0, "", " L");

    // 3. Recursos e Insumos
    const totalRecursos = kpis.recursos?.total_recursos ?? 0;
    animarNumero("subKpiRecursos", totalRecursos, false, "", " items");
}


function renderizarGraficoCargos(cargos) {
    const canvas = document.getElementById("chartCargos");
    if (!canvas) return;

    if (!cargos.length) {
        canvas.parentElement.innerHTML = '<p class="empty-hint">Sin datos de obreros para graficar.</p>';
        return;
    }

    const labels = cargos.map(c => c.cargo || "Otros");
    const valores = cargos.map(c => Number(c.cantidad) || 0);

    if (typeof Chart !== "undefined") {
        if (chartCargosInstance) chartCargosInstance.destroy();

        // Plugin personalizado para mostrar número total en el centro del Doughnut
        const centroDonaPlugin = {
            id: "centroDonaTexto",
            beforeDraw(chart) {
                if (chart.config.type !== "doughnut") return;
                const { ctx } = chart;
                const meta = chart.getDatasetMeta(0);
                if (!meta || !meta.data || !meta.data.length) return;

                const x = meta.data[0].x;
                const y = meta.data[0].y;
                const total = chart.config.data.datasets[0].data.reduce((a, b) => a + b, 0);

                ctx.save();
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";

                ctx.font = "bold 24px Inter, sans-serif";
                ctx.fillStyle = "#0f172a";
                ctx.fillText(String(total), x, y - 8);

                ctx.font = "600 10.5px Inter, sans-serif";
                ctx.fillStyle = "#64748b";
                ctx.fillText("OBREROS", x, y + 14);

                ctx.restore();
            }
        };

        chartCargosInstance = new Chart(canvas, {
            type: "doughnut",
            data: {
                labels: labels,
                datasets: [{
                    data: valores,
                    backgroundColor: COLORES_PORTICO.slice(0, labels.length),
                    borderWidth: 2,
                    borderColor: "#ffffff",
                    hoverOffset: 6
                }]
            },
            plugins: [centroDonaPlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: window.innerWidth >= 1400 ? "right" : "bottom",
                        labels: {
                            boxWidth: 12,
                            padding: 12,
                            font: { family: "Inter", size: 11, weight: "600" },
                            color: "#334155"
                        }
                    },
                    tooltip: {
                        backgroundColor: "#0f172a",
                        titleFont: { family: "Inter", size: 12, weight: "600" },
                        bodyFont: { family: "Inter", size: 12 },
                        padding: 10,
                        cornerRadius: 8,
                        callbacks: {
                            label: function(ctx) {
                                const total = ctx.dataset.data.reduce((a, b) => a + b, 0);
                                const val = ctx.raw || 0;
                                const pct = total > 0 ? Math.round((val / total) * 100) : 0;
                                return ` ${ctx.label}: ${val} obreros (${pct}%)`;
                            }
                        }
                    }
                },
                cutout: "68%"
            }
        });
    } else {
        renderizarFallbackCargos(canvas.parentElement, cargos);
    }
}

function renderizarGraficoHoras(obras) {
    const canvas = document.getElementById("chartHorasObras");
    if (!canvas) return;

    if (!obras.length) {
        canvas.parentElement.innerHTML = '<p class="empty-hint">Sin registros de horas para graficar.</p>';
        return;
    }

    const labels = obras.map(o => o.nombre ? (o.nombre.length > 20 ? o.nombre.substring(0, 18) + "..." : o.nombre) : "Obra");
    const valores = obras.map(o => Number(o.total_horas) || 0);

    if (typeof Chart !== "undefined") {
        if (chartHorasInstance) chartHorasInstance.destroy();

        chartHorasInstance = new Chart(canvas, {
            type: "bar",
            data: {
                labels: labels,
                datasets: [{
                    label: "Horas Registradas",
                    data: valores,
                    backgroundColor: "#2563eb",
                    hoverBackgroundColor: "#1d4ed8",
                    borderRadius: 8,
                    borderSkipped: false,
                    maxBarThickness: 45
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: "#0f172a",
                        titleFont: { family: "Inter", size: 12, weight: "600" },
                        bodyFont: { family: "Inter", size: 12 },
                        padding: 10,
                        cornerRadius: 8,
                        callbacks: {
                            label: function(ctx) {
                                return ` ${ctx.raw.toLocaleString("es-AR")} horas trabajadas`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: {
                            font: { family: "Inter", size: 11, weight: "500" },
                            color: "#64748b",
                            maxRotation: 20
                        }
                    },
                    y: {
                        grid: { color: "#f1f5f9" },
                        ticks: {
                            font: { family: "Inter", size: 11 },
                            color: "#64748b",
                            callback: function(val) {
                                return val + " h";
                            }
                        }
                    }
                }
            }
        });
    } else {
        renderizarFallbackHoras(canvas.parentElement, obras);
    }
}






function escapeHtml(str) {
    if (!str) return "";
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function renderizarFallbackCargos(container, cargos) {
    container.innerHTML = `
        <div class="fallback-list">
            ${cargos.slice(0, 5).map((c, i) => `
                <div class="fallback-row">
                    <span class="fallback-badge-dot">
                        <span class="fallback-dot" style="background:${COLORES_PORTICO[i % COLORES_PORTICO.length]};"></span>
                        ${escapeHtml(c.cargo)}
                    </span>
                    <strong>${c.cantidad}</strong>
                </div>
            `).join("")}
        </div>
    `;
}

function renderizarFallbackHoras(container, obras) {
    container.innerHTML = `
        <div class="fallback-list">
            ${obras.slice(0, 5).map(o => `
                <div class="fallback-row">
                    <span>${escapeHtml(o.nombre)}</span>
                    <strong>${o.total_horas}h</strong>
                </div>
            `).join("")}
        </div>
    `;
}