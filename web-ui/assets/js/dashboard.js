document.addEventListener("DOMContentLoaded", () => {
    inicializarFecha();
    cargarMetricasDashboard();
});

// Paleta de colores de Pórtico para gráficos
const COLORES_PORTICO = [
    "#954043", // Borgoña oscuro institucional
    "#b54747", // Rojo terracota primario
    "#c25e5e", // Terracota claro
    "#d97d7d", // Rosa suave
    "#8e3a3d", // Borgoña fuerte
    "#e29595", // Rosa pastel
    "#d97706", // Ámbar constructivo
    "#475569", // Pizarra
    "#64748b", // Pizarra suave
    "#94a3b8"  // Gris azulado
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
    // Capitalizar primera letra
    el.textContent = fechaTexto.charAt(0).toUpperCase() + fechaTexto.slice(1);
}

async function cargarMetricasDashboard() {
    try {
        let datos;

        if (window.chrome && window.chrome.webview) {
            datos = await sendDesktopRequest("dashboard_metricas", {}, "dashboard_metricas_response");
        } else {
            const apiBase = window.location.origin.includes("localhost") || window.location.origin.includes("127.0.0.1")
                ? "/api"
                : "api";
            const res = await fetch(`${apiBase}/dashboard.php`, { credentials: "include" });
            if (!res.ok) throw new Error("Error al obtener métricas del servidor.");
            datos = await res.json();
        }

        if (datos && datos.data) {
            renderizarKPIs(datos.data.kpis);
            renderizarGraficoCargos(datos.data.distribucion_cargos || []);
            renderizarGraficoHoras(datos.data.horas_por_obra || []);
            renderizarAlertas(datos.data.alertas_recientes || []);
        }
    } catch (error) {
        console.error("Error cargando dashboard:", error);
    }
}

function animarNumero(elementoId, valorFinal, esDecimal = false) {
    const el = document.getElementById(elementoId);
    if (!el) return;

    const inicio = 0;
    const duracion = 800;
    const pasos = 25;
    const incremento = valorFinal / pasos;
    let actual = inicio;
    let contador = 0;

    const timer = setInterval(() => {
        contador++;
        actual += incremento;
        if (contador >= pasos) {
            clearInterval(timer);
            el.textContent = esDecimal ? valorFinal.toLocaleString("es-AR", { minimumFractionDigits: 1, maximumFractionDigits: 1 }) : valorFinal.toLocaleString("es-AR");
        } else {
            el.textContent = esDecimal ? actual.toLocaleString("es-AR", { minimumFractionDigits: 1, maximumFractionDigits: 1 }) : Math.round(actual).toLocaleString("es-AR");
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

    const elObrasBar = document.getElementById("kpiObrasBar");
    if (elObrasBar && totalObras > 0) {
        elObrasBar.style.width = `${Math.round((activasObras / totalObras) * 100)}%`;
    }

    // 2. Obreros
    const activosObreros = kpis.obreros?.activos ?? 0;
    const totalObreros = kpis.obreros?.total ?? 0;
    animarNumero("kpiObrerosActivos", activosObreros);
    const elObrerosTotal = document.getElementById("kpiObrerosTotal");
    if (elObrerosTotal) elObrerosTotal.textContent = `${totalObreros} registrados`;

    const elObrerosBar = document.getElementById("kpiObrerosBar");
    if (elObrerosBar && totalObreros > 0) {
        elObrerosBar.style.width = `${Math.round((activosObreros / totalObreros) * 100)}%`;
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
    if (elMaqAsignada) elMaqAsignada.textContent = `${asignadaMaq} equipos en obra actualmente`;

    // 4. Horas
    const totalHoras = kpis.horas?.total_horas ?? 0;
    const totalRegistros = kpis.horas?.total_registros ?? 0;
    animarNumero("kpiTotalHoras", totalHoras, true);
    const elTotalRegistros = document.getElementById("kpiTotalRegistros");
    if (elTotalRegistros) elTotalRegistros.textContent = `${totalRegistros} asistencias`;
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

        chartCargosInstance = new Chart(canvas, {
            type: "doughnut",
            data: {
                labels: labels,
                datasets: [{
                    data: valores,
                    backgroundColor: COLORES_PORTICO.slice(0, labels.length),
                    borderWidth: 2,
                    borderColor: "#ffffff"
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: "right",
                        labels: {
                            boxWidth: 12,
                            padding: 12,
                            font: { family: "Inter", size: 11, weight: "500" },
                            color: "#475569"
                        }
                    },
                    tooltip: {
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
        // Fallback visual si Chart.js no estuviera disponible
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

    const labels = obras.map(o => o.nombre ? (o.nombre.length > 22 ? o.nombre.substring(0, 20) + "..." : o.nombre) : "Obra");
    const valores = obras.map(o => Number(o.total_horas) || 0);

    if (typeof Chart !== "undefined") {
        if (chartHorasInstance) chartHorasInstance.destroy();

        chartHorasInstance = new Chart(canvas, {
            type: "bar",
            data: {
                labels: labels,
                datasets: [{
                    label: "Horas Trabajadas",
                    data: valores,
                    backgroundColor: "#b54747",
                    hoverBackgroundColor: "#954043",
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function(ctx) {
                                return ` ${ctx.raw} horas registradas`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: {
                            font: { family: "Inter", size: 11 },
                            color: "#64748b",
                            maxRotation: 20
                        }
                    },
                    y: {
                        grid: { color: "#f1f5f9" },
                        ticks: {
                            font: { family: "Inter", size: 11 },
                            color: "#64748b"
                        }
                    }
                }
            }
        });
    } else {
        renderizarFallbackHoras(canvas.parentElement, obras);
    }
}

function renderizarAlertas(alertas) {
    const container = document.getElementById("alertsList");
    if (!container) return;

    if (!alertas.length) {
        container.innerHTML = `
            <div style="display:flex; align-items:center; gap:8px; padding:12px; background:#f0fdf4; border-radius:10px; color:#166534; font-size:13px; font-weight:500;">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                Todos los certificados y documentación técnica se encuentran al día.
            </div>
        `;
        return;
    }

    container.innerHTML = alertas.map(a => {
        const dias = Number(a.dias_restantes);
        let badgeText, badgeClass;

        if (dias < 0) {
            badgeText = `Venció hace ${Math.abs(dias)}d`;
            badgeClass = "vencido";
        } else if (dias === 0) {
            badgeText = "Vence hoy";
            badgeClass = "vencido";
        } else {
            badgeText = `Vence en ${dias}d`;
            badgeClass = "por_vencer";
        }

        return `
            <div class="alert-row">
                <div class="alert-left">
                    <svg class="alert-icon-svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    <div>
                        <div style="font-weight: 600; color: #1e293b;">${escapeHtml(a.nombre_maquinaria || "Equipo")} ${a.marca ? `(${escapeHtml(a.marca)})` : ''}</div>
                        <div style="font-size: 11.5px; color: #64748b;">${escapeHtml(a.nombre_archivo || "Certificado técnico")}</div>
                    </div>
                </div>
                <span class="alert-badge-tag ${badgeClass}">${badgeText}</span>
            </div>
        `;
    }).join("");
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
        <div style="display:flex; flex-direction:column; gap:8px; width:100%;">
            ${cargos.slice(0, 5).map((c, i) => `
                <div style="display:flex; justify-content:space-between; font-size:12.5px;">
                    <span style="display:flex; align-items:center; gap:6px;">
                        <span style="width:10px; height:10px; border-radius:50%; background:${COLORES_PORTICO[i % COLORES_PORTICO.length]}; display:inline-block;"></span>
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
        <div style="display:flex; flex-direction:column; gap:8px; width:100%;">
            ${obras.slice(0, 5).map(o => `
                <div style="display:flex; justify-content:space-between; font-size:12.5px;">
                    <span>${escapeHtml(o.nombre)}</span>
                    <strong>${o.total_horas}h</strong>
                </div>
            `).join("")}
        </div>
    `;
}
