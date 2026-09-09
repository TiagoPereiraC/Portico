document.addEventListener("DOMContentLoaded", () => {
    inicializarFecha();
    inicializarDropdownNotificaciones();
    inicializarColapsableAnaliticas();
    inicializarTabsAlertas();
    inicializarMarcarLeidas();
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

function inicializarDropdownNotificaciones() {
    const btn = document.getElementById("btnNotifications");
    const dropdown = document.getElementById("notificationsDropdown");
    const wrapper = document.getElementById("notificationsWrapper");

    if (!btn || !dropdown) return;

    btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const estaAbierto = dropdown.style.display === "block";
        dropdown.style.display = estaAbierto ? "none" : "block";
    });

    document.addEventListener("click", (e) => {
        if (wrapper && !wrapper.contains(e.target)) {
            dropdown.style.display = "none";
        }
    });

    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && dropdown.style.display === "block") {
            dropdown.style.display = "none";
        }
    });
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

function inicializarTabsAlertas() {
    const btnMaq = document.getElementById("tabNotifMaq") || document.getElementById("tabAlertasMaq");
    const btnObr = document.getElementById("tabNotifObr") || document.getElementById("tabAlertasObr");

    if (btnMaq) {
        btnMaq.addEventListener("click", () => cambiarTabAlertas("maquinaria"));
    }
    if (btnObr) {
        btnObr.addEventListener("click", () => cambiarTabAlertas("obreros"));
    }
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
let alertasMaquinariaCache = [];
let alertasContratosCache = [];
let tabAlertaActual = "maquinaria";

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
            const apiBase = window.location.origin.includes("localhost") || window.location.origin.includes("127.0.0.1")
                ? "/api"
                : "api";
            const res = await fetch(`${apiBase}/dashboard.php`, { credentials: "include" });
            if (!res.ok) throw new Error("Error al obtener métricas del servidor.");
            datos = await res.json();
        }

        if (datos && datos.data) {
            alertasMaquinariaCache = datos.data.alertas_recientes || [];
            alertasContratosCache = datos.data.alertas_contratos || [];

            renderizarKPIs(datos.data.kpis);
            renderizarResumenOperativo(datos.data.kpis);
            renderizarGraficoCargos(datos.data.distribucion_cargos || []);
            renderizarGraficoHoras(datos.data.horas_por_obra || []);
            renderizarAlertas();
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
    const elObrasBar = document.getElementById("kpiObrasBar");
    if (elObrasBar) {
        const barraWidth = totalObras > 0 ? Math.round((activasObras / totalObras) * 100) : 0;
        elObrasBar.style.width = `${barraWidth}%`;
    }
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

    const elObrerosBar = document.getElementById("kpiObrerosBar");
    if (elObrerosBar && totalObreros > 0) {
        elObrerosBar.style.width = `${Math.round((activosObreros / totalObreros) * 100)}%`;
    }

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
    if (elMaqAsignada) elMaqAsignada.textContent = `${asignadaMaq} equipos en obra actualmente`;

    // 4. Combustible & Insumos
    const litrosComb = kpis.combustible?.total_litros ?? 0;
    const gastoComb = kpis.combustible?.total_gasto ?? 0;
    const dieselLitros = kpis.combustible?.diesel_litros ?? 0;
    const naftaLitros = kpis.combustible?.nafta_litros ?? 0;

    animarNumero("kpiCombustibleLitros", litrosComb, litrosComb % 1 !== 0, "", " L");
    const elCombGasto = document.getElementById("kpiCombustibleGasto");
    if (elCombGasto) {
        elCombGasto.textContent = gastoComb > 0 ? `$ ${gastoComb.toLocaleString("es-AR")}` : "$ 0";
    }

    const elCombDetalle = document.getElementById("kpiCombustibleDetalle");
    if (elCombDetalle) {
        elCombDetalle.textContent = `Diesel: ${Math.round(dieselLitros)}L | Nafta: ${Math.round(naftaLitros)}L`;
    }
}

function renderizarResumenOperativo(kpis) {
    if (!kpis) return;

    // Horas acumuladas
    const totalHoras = kpis.horas?.total_horas ?? 0;
    const totalRegistros = kpis.horas?.total_registros ?? 0;
    animarNumero("subKpiHoras", totalHoras, true, "", " hrs");
    const elRegistros = document.getElementById("subKpiRegistros");
    if (elRegistros) elRegistros.textContent = `${totalRegistros} registros de asistencia`;

    // Avance de Contratos
    const pctAvance = kpis.actividades?.porcentaje_avance ?? 0;
    const tareasComp = kpis.actividades?.tareas_completadas ?? 0;
    const totalTareas = kpis.actividades?.total_tareas ?? 0;
    animarNumero("subKpiAvanceContratos", pctAvance, true, "", "%");
    const elTareas = document.getElementById("subKpiTareas");
    if (elTareas) {
        elTareas.textContent = totalTareas > 0
            ? `${tareasComp} de ${totalTareas} tareas completadas`
            : "Sin actividades de contrato registradas";
    }

    // Recursos
    const totalRecursos = kpis.recursos?.total_recursos ?? 0;
    const totalMat = kpis.recursos?.total_materiales ?? 0;
    const totalHerr = kpis.recursos?.total_herramientas ?? 0;
    animarNumero("subKpiRecursos", totalRecursos, false, "", " items");
    const elRecursosDetalle = document.getElementById("subKpiRecursosDetalle");
    if (elRecursosDetalle) {
        elRecursosDetalle.textContent = `${totalMat} materiales | ${totalHerr} herramientas`;
    }
}

function cambiarTabAlertas(tipo) {
    tabAlertaActual = tipo;
    const btnMaq = document.getElementById("tabNotifMaq") || document.getElementById("tabAlertasMaq");
    const btnObr = document.getElementById("tabNotifObr") || document.getElementById("tabAlertasObr");

    if (tipo === "maquinaria") {
        if (btnMaq) btnMaq.classList.add("active");
        if (btnObr) btnObr.classList.remove("active");
    } else {
        if (btnMaq) btnMaq.classList.remove("active");
        if (btnObr) btnObr.classList.add("active");
    }

    renderizarAlertas();
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
                        position: window.innerWidth >= 1400 ? "right" : "bottom",
                        labels: {
                            boxWidth: 12,
                            padding: 10,
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
                    backgroundColor: "#3b82f6",
                    hoverBackgroundColor: "#2563eb",
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

function renderizarAlertas() {
    const container = document.getElementById("notifListBody") || document.getElementById("alertsList");
    const badge = document.getElementById("notificationsBadge");
    const countTag = document.getElementById("notifCountTag");

    const noLeidasMaq = alertasMaquinariaCache.filter(a => !a.leido).length;
    const noLeidasObr = alertasContratosCache.filter(a => !a.leido).length;
    const totalAlertas = noLeidasMaq + noLeidasObr;

    if (badge) {
        if (totalAlertas > 0) {
            badge.textContent = totalAlertas > 99 ? "99+" : String(totalAlertas);
            badge.style.display = "inline-flex";
        } else {
            badge.style.display = "none";
        }
    }

    if (countTag) {
        countTag.textContent = `${totalAlertas} alerta${totalAlertas === 1 ? "" : "s"}`;
    }

    if (!container) return;

    const lista = (tabAlertaActual === "maquinaria") ? alertasMaquinariaCache : alertasContratosCache;

    if (!lista || !lista.length) {
        const mensajeVacio = (tabAlertaActual === "maquinaria")
            ? "Todos los certificados y documentación técnica de maquinaria se encuentran al día."
            : "Todos los contratos de personal se encuentran vigentes y al día.";

        container.innerHTML = `
            <div class="alert-empty-notice">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                <span>${mensajeVacio}</span>
            </div>
        `;
        return;
    }

    container.innerHTML = lista.map(a => {
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

        const titulo = a.tipo_alerta === "obrero"
            ? escapeHtml(a.nombre_obrero || "Obrero")
            : `${escapeHtml(a.nombre_maquinaria || "Equipo")} ${a.marca ? `(${escapeHtml(a.marca)})` : ''}`;

        const subtitulo = a.tipo_alerta === "obrero"
            ? `DNI: ${escapeHtml(a.documento || "S/D")} · Vencimiento contrato: ${escapeHtml(a.fecha_vencimiento || "")}`
            : `${escapeHtml(a.nombre_archivo || "Certificado técnico")} · Vencimiento: ${escapeHtml(a.fecha_vencimiento || "")}`;

        const idRef = a.tipo_alerta === "obrero" ? a.id_contrato_obrero : a.id_certificado;
        const estaLeida = Boolean(a.leido);

        const readActionHtml = estaLeida
            ? `<span class="alert-badge-tag leido">Leída</span>`
            : `<button type="button" class="btn-mark-single-read" data-tipo="${a.tipo_alerta}" data-id="${idRef}" title="Marcar como leída">
                 <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                 <span>Leída</span>
               </button>`;

        return `
            <div class="alert-row ${estaLeida ? 'is-read' : ''}">
                <div class="alert-left">
                    <svg class="alert-icon-svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    <div>
                        <div class="alert-item-title">${titulo}</div>
                        <div class="alert-item-subtitle">${subtitulo}</div>
                    </div>
                </div>
                <div class="alert-actions">
                    <span class="alert-badge-tag ${badgeClass}">${badgeText}</span>
                    ${readActionHtml}
                </div>
            </div>
        `;
    }).join("");
}

function inicializarMarcarLeidas() {
    const btnTodas = document.getElementById("btnMarcarTodasLeidas");
    if (btnTodas) {
        btnTodas.addEventListener("click", (e) => {
            e.stopPropagation();
            marcarTodasNotificacionesLeidas();
        });
    }

    const container = document.getElementById("notifListBody");
    if (container) {
        container.addEventListener("click", (e) => {
            const btn = e.target.closest(".btn-mark-single-read");
            if (!btn) return;
            e.stopPropagation();
            const tipo = btn.dataset.tipo;
            const id = Number(btn.dataset.id);
            if (tipo && id) {
                marcarNotificacionLeida(tipo, id);
            }
        });
    }
}

async function marcarNotificacionLeida(tipo, idReferencia) {
    if (tipo === "maquinaria") {
        const item = alertasMaquinariaCache.find(x => Number(x.id_certificado) === idReferencia);
        if (item) item.leido = 1;
    } else if (tipo === "obrero") {
        const item = alertasContratosCache.find(x => Number(x.id_contrato_obrero) === idReferencia);
        if (item) item.leido = 1;
    }
    renderizarAlertas();

    try {
        if (window.chrome && window.chrome.webview) {
            await sendDesktopRequest("notificacion_marcar_leida", { tipo, id_referencia: idReferencia }, "notificacion_marcar_leida_response");
        } else {
            const apiBase = window.location.origin.includes("localhost") || window.location.origin.includes("127.0.0.1")
                ? "/api"
                : "api";
            await fetch(`${apiBase}/marcar_notificacion.php`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                credentials: "include",
                body: JSON.stringify({ tipo, id_referencia: idReferencia })
            });
        }
    } catch (err) {
        console.error("Error al marcar notificación como leída:", err);
    }
}

async function marcarTodasNotificacionesLeidas() {
    alertasMaquinariaCache.forEach(x => x.leido = 1);
    alertasContratosCache.forEach(x => x.leido = 1);
    renderizarAlertas();

    try {
        if (window.chrome && window.chrome.webview) {
            await sendDesktopRequest("notificacion_marcar_leida", { tipo: "todas" }, "notificacion_marcar_leida_response");
        } else {
            const apiBase = window.location.origin.includes("localhost") || window.location.origin.includes("127.0.0.1")
                ? "/api"
                : "api";
            await fetch(`${apiBase}/marcar_notificacion.php`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                credentials: "include",
                body: JSON.stringify({ tipo: "todas" })
            });
        }
    } catch (err) {
        console.error("Error al marcar todas las notificaciones como leídas:", err);
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
