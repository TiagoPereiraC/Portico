/* Campana de notificaciones compartida por todas las secciones.
 * Requiere el markup #notificationsWrapper (campana + dropdown) en el navbar.
 * Funciona en modo web (API) y escritorio (IPC WebView2).
 */
(function () {
    "use strict";

    function resolveApiBase() {
        const path = window.location.pathname;
        const idx = path.lastIndexOf("/web-ui/");

        if (idx !== -1) {
            return window.location.origin + path.substring(0, idx) + "/api";
        }

        return window.location.origin + "/api";
    }

    const API_BASE = resolveApiBase();

    let alertasMaquinaria = [];
    let alertasContratos = [];
    let tabActual = "maquinaria";

    function escapeHtml(str) {
        if (!str) return "";
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    function sendDesktopRequest(type, payload) {
        return new Promise(function (resolve, reject) {
            if (!window.chrome || !window.chrome.webview) {
                reject(new Error("No se detectó el entorno de escritorio."));
                return;
            }

            const requestId = type + "_" + Date.now() + "_" + Math.random().toString(16).slice(2);
            const timer = setTimeout(function () {
                window.chrome.webview.removeEventListener("message", onMessage);
                reject(new Error("Tiempo de espera agotado."));
            }, 12000);

            function onMessage(event) {
                let data = event.data;
                if (typeof data === "string") {
                    try {
                        data = JSON.parse(data);
                    } catch (e) {
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
            window.chrome.webview.postMessage(JSON.stringify(Object.assign({ type: type, requestId: requestId }, payload)));
        });
    }

    async function obtenerCsrf() {
        const resp = await fetch(API_BASE + "/csrf.php", { credentials: "include" });
        const data = await resp.json();
        return (data && data.token) || "";
    }

    document.addEventListener("DOMContentLoaded", function () {
        const btn = document.getElementById("btnNotifications");
        if (!btn) return;

        const dropdown = document.getElementById("notificationsDropdown");
        const wrapper = document.getElementById("notificationsWrapper");

        btn.addEventListener("click", function (e) {
            e.stopPropagation();
            const abierto = dropdown.style.display === "block";
            dropdown.style.display = abierto ? "none" : "block";
        });

        document.addEventListener("click", function (e) {
            if (wrapper && !wrapper.contains(e.target)) {
                dropdown.style.display = "none";
            }
        });

        document.addEventListener("keydown", function (e) {
            if (e.key === "Escape" && dropdown.style.display === "block") {
                dropdown.style.display = "none";
            }
        });

        const btnMaq = document.getElementById("tabNotifMaq");
        const btnObr = document.getElementById("tabNotifObr");

        if (btnMaq) btnMaq.addEventListener("click", function () { cambiarTab("maquinaria"); });
        if (btnObr) btnObr.addEventListener("click", function () { cambiarTab("obreros"); });

        const btnTodas = document.getElementById("btnMarcarTodasLeidas");
        if (btnTodas) {
            btnTodas.addEventListener("click", function (e) {
                e.stopPropagation();
                marcarTodas();
            });
        }

        const lista = document.getElementById("notifListBody");
        if (lista) {
            lista.addEventListener("click", function (e) {
                const boton = e.target.closest(".btn-mark-single-read");
                if (!boton) return;
                e.stopPropagation();

                const tipo = boton.dataset.tipo;
                const id = Number(boton.dataset.id);

                if (tipo && id) {
                    marcarUna(tipo, id);
                }
            });
        }

        cargar();
    });

    function cambiarTab(tipo) {
        tabActual = tipo;

        const btnMaq = document.getElementById("tabNotifMaq");
        const btnObr = document.getElementById("tabNotifObr");

        if (tipo === "maquinaria") {
            if (btnMaq) btnMaq.classList.add("active");
            if (btnObr) btnObr.classList.remove("active");
        } else {
            if (btnMaq) btnMaq.classList.remove("active");
            if (btnObr) btnObr.classList.add("active");
        }

        renderizar();
    }

    async function cargar() {
        try {
            let datos;

            if (window.chrome && window.chrome.webview) {
                datos = await sendDesktopRequest("dashboard_metricas", {});
            } else {
                const res = await fetch(API_BASE + "/dashboard.php", { credentials: "include" });
                if (!res.ok) throw new Error("Error al obtener alertas del servidor.");
                datos = await res.json();
            }

            if (datos && datos.data) {
                alertasMaquinaria = datos.data.alertas_recientes || [];
                alertasContratos = datos.data.alertas_contratos || [];
            }
        } catch (e) {
            console.error("Error cargando notificaciones:", e);
        }

        renderizar();
    }

    function renderizar() {
        const container = document.getElementById("notifListBody");
        const badge = document.getElementById("notificationsBadge");
        const countTag = document.getElementById("notifCountTag");

        const noLeidasMaq = alertasMaquinaria.filter(function (a) { return !a.leido; }).length;
        const noLeidasObr = alertasContratos.filter(function (a) { return !a.leido; }).length;
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
            countTag.textContent = totalAlertas + " alerta" + (totalAlertas === 1 ? "" : "s");
        }

        if (!container) return;

        const lista = (tabActual === "maquinaria" ? alertasMaquinaria : alertasContratos)
            .filter(function (a) { return !Number(a.leido); });

        if (!lista || !lista.length) {
            const mensajeVacio = (tabActual === "maquinaria")
                ? "Todos los certificados y documentación técnica de maquinaria se encuentran al día."
                : "Todos los contratos de personal se encuentran vigentes y al día.";

            container.innerHTML =
                '<div class="alert-empty-notice">' +
                '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>' +
                "<span>" + mensajeVacio + "</span>" +
                "</div>";
            return;
        }

        container.innerHTML = lista.map(function (a) {
            const dias = Number(a.dias_restantes);
            let badgeText, badgeClass;

            if (dias < 0) {
                badgeText = "Venció hace " + Math.abs(dias) + "d";
                badgeClass = "vencido";
            } else if (dias === 0) {
                badgeText = "Vence hoy";
                badgeClass = "vencido";
            } else {
                badgeText = "Vence en " + dias + "d";
                badgeClass = "por_vencer";
            }

            const titulo = a.tipo_alerta === "obrero"
                ? escapeHtml(a.nombre_obrero || "Obrero")
                : escapeHtml(a.nombre_maquinaria || "Equipo") + (a.marca ? " (" + escapeHtml(a.marca) + ")" : "");

            const subtitulo = a.tipo_alerta === "obrero"
                ? "DNI: " + escapeHtml(a.documento || "S/D") + " · Vencimiento contrato: " + escapeHtml(a.fecha_vencimiento || "")
                : escapeHtml(a.nombre_archivo || "Certificado técnico") + " · Vencimiento: " + escapeHtml(a.fecha_vencimiento || "");

            const idRef = a.tipo_alerta === "obrero" ? a.id_contrato_obrero : a.id_certificado;

            const readActionHtml = '<button type="button" class="btn-mark-single-read" data-tipo="' + a.tipo_alerta + '" data-id="' + idRef + '" title="Marcar como visto">' +
                '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>' +
                "<span>Visto</span>" +
                "</button>";

            return '<div class="alert-row">' +
                '<div class="alert-left">' +
                    '<svg class="alert-icon-svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>' +
                    '<div class="alert-text-wrap">' +
                        '<div class="alert-item-title">' + titulo + "</div>" +
                        '<div class="alert-item-subtitle">' + subtitulo + "</div>" +
                    "</div>" +
                "</div>" +
                '<div class="alert-actions-col">' +
                    '<span class="alert-badge-tag ' + badgeClass + '">' + badgeText + "</span>" +
                    readActionHtml +
                "</div>" +
            "</div>";
        }).join("");
    }

    async function marcarUna(tipo, idReferencia) {
        if (tipo === "maquinaria") {
            const item = alertasMaquinaria.find(function (x) { return Number(x.id_certificado) === idReferencia; });
            if (item) item.leido = 1;
        } else if (tipo === "obrero") {
            const item = alertasContratos.find(function (x) { return Number(x.id_contrato_obrero) === idReferencia; });
            if (item) item.leido = 1;
        }

        renderizar();

        try {
            if (window.chrome && window.chrome.webview) {
                await sendDesktopRequest("notificacion_marcar_leida", { tipo: tipo, id_referencia: idReferencia });
            } else {
                const csrf = await obtenerCsrf();

                await fetch(API_BASE + "/marcar_notificacion.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
                    credentials: "include",
                    body: JSON.stringify({ tipo: tipo, id_referencia: idReferencia })
                });
            }
        } catch (err) {
            console.error("Error al marcar notificación como leída:", err);
        }
    }

    async function marcarTodas() {
        alertasMaquinaria.forEach(function (x) { x.leido = 1; });
        alertasContratos.forEach(function (x) { x.leido = 1; });

        renderizar();

        try {
            if (window.chrome && window.chrome.webview) {
                await sendDesktopRequest("notificacion_marcar_leida", { tipo: "todas" });
            } else {
                const csrf = await obtenerCsrf();

                await fetch(API_BASE + "/marcar_notificacion.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
                    credentials: "include",
                    body: JSON.stringify({ tipo: "todas" })
                });
            }
        } catch (err) {
            console.error("Error al marcar todas las notificaciones como leídas:", err);
        }
    }
})();
