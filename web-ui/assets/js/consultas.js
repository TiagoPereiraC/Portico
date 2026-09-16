let obrerosList = [];
let debounceTimer = null;

document.addEventListener('DOMContentLoaded', () => {
    inicializarAutocompletadoObreros();
    cargarObreros();

    document
        .getElementById('btnBuscar')
        .addEventListener('click', buscarConsultas);
});

const feedback = document.getElementById('feedback');
const pagination = document.getElementById('pagination');
const paginationInfo = document.getElementById('paginationInfo');
const paginationPage = document.getElementById('paginationPage');
const paginationPrev = document.getElementById('paginationPrev');
const paginationNext = document.getElementById('paginationNext');

const ITEMS_POR_PAGINA = 10;
let paginaActual = 1;
let totalPaginas = 1;
let totalRegistros = 0;
let filtrosActivos = null;

if (paginationPrev) {
    paginationPrev.addEventListener('click', () => cambiarPagina(-1));
}
if (paginationNext) {
    paginationNext.addEventListener('click', () => cambiarPagina(1));
}

function mostrarFeedback(mensaje, tipo = 'info') {
    if (!feedback) return;
    const icono = tipo === 'error' ? 'fa-circle-exclamation' : tipo === 'success' ? 'fa-circle-check' : 'fa-triangle-exclamation';
    feedback.innerHTML = `<i class="fas ${icono}"></i><span>${escapeHtml(mensaje)}</span>`;
    feedback.className = `feedback-msg ${tipo}`;
    feedback.classList.remove('hidden');
}

function ocultarFeedback() {
    if (!feedback) return;
    feedback.classList.add('hidden');
}

function sendDesktopRequest(type, payload, responseType) {
    return new Promise((resolve, reject) => {
        if (!window.chrome?.webview) {
            reject(new Error("No se detectó el entorno de escritorio."));
            return;
        }

        const requestId = `${type}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
        const timer = setTimeout(() => {
            window.chrome.webview.removeEventListener("message", onMessage);
            reject(new Error("Tiempo de espera agotado al consultar datos."));
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
                reject(new Error(data.error || "Error al procesar la solicitud en escritorio."));
            }
        }

        window.chrome.webview.addEventListener("message", onMessage);
        window.chrome.webview.postMessage(JSON.stringify({ type, requestId, ...payload }));
    });
}

const obreroHiddenInput = document.getElementById('obrero');
const obreroSearchInput = document.getElementById('obreroSearchInput');
const obreroDropdown = document.getElementById('obreroDropdown');
const obreroClearBtn = document.getElementById('obreroClearBtn');
const obreroSelectedCard = document.getElementById('obreroSelectedCard');
const obreroSelectedText = document.getElementById('obreroSelectedText');

function inicializarAutocompletadoObreros() {
    if (!obreroSearchInput || !obreroDropdown) return;

    obreroSearchInput.addEventListener('focus', () => {
        filtrarYRenderizarDropdown(obreroSearchInput.value);
    });

    obreroSearchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            filtrarYRenderizarDropdown(e.target.value);
        }, 150);
    });

    if (obreroClearBtn) {
        obreroClearBtn.addEventListener('click', () => {
            limpiarSeleccionObrero();
            filtrarYRenderizarDropdown('');
            obreroSearchInput.focus();
        });
    }

    document.addEventListener('click', (e) => {
        if (!e.target.closest('.obrero-combobox-wrap')) {
            obreroDropdown.classList.add('hidden');
        }
    });

    obreroDropdown.addEventListener('click', (e) => {
        const item = e.target.closest('.obrero-option-item');
        if (!item) return;

        const id = item.dataset.id;
        if (id === '') {
            limpiarSeleccionObrero();
            obreroDropdown.classList.add('hidden');
            return;
        }

        const obrero = obrerosList.find(o => String(o.id_obrero) === String(id));
        if (obrero) {
            seleccionarObrero(obrero);
        }
        obreroDropdown.classList.add('hidden');
    });
}

function filtrarYRenderizarDropdown(query) {
    const q = (query || '').toLowerCase().trim();
    let filtrados = obrerosList;

    if (q) {
        filtrados = obrerosList.filter(o => {
            const nom = `${o.nombre || ''} ${o.apellido || ''}`.toLowerCase();
            const doc = (o.documento || '').toLowerCase();
            const car = (o.cargo || '').toLowerCase();
            return nom.includes(q) || doc.includes(q) || car.includes(q);
        });
    }

    let html = `
        <div class="obrero-option-item" data-id="">
            <div class="obrero-option-info">
                <span class="obrero-option-name">Todos los obreros</span>
                <span class="obrero-option-meta">Consulta general de toda la plantilla</span>
            </div>
            <span class="obrero-option-badge">General</span>
        </div>
    `;

    if (!filtrados.length && q) {
        html += `<div style="padding:10px;text-align:center;font-size:12.5px;color:#888;">No se encontraron obreros para "${escapeHtml(query)}"</div>`;
    } else {
        html += filtrados.slice(0, 30).map(o => `
            <div class="obrero-option-item ${obreroHiddenInput.value === String(o.id_obrero) ? 'selected' : ''}" data-id="${o.id_obrero}">
                <div class="obrero-option-info">
                    <span class="obrero-option-name">${escapeHtml(o.nombre)} ${escapeHtml(o.apellido || '')}</span>
                    <span class="obrero-option-meta">DNI: ${escapeHtml(o.documento || 'S/D')}</span>
                </div>
                <span class="obrero-option-badge">${escapeHtml(o.cargo || 'Obrero')}</span>
            </div>
        `).join('');
    }

    obreroDropdown.innerHTML = html;
    obreroDropdown.classList.remove('hidden');
}

function seleccionarObrero(obrero) {
    obreroHiddenInput.value = obrero.id_obrero;
    obreroSearchInput.value = `${obrero.nombre} ${obrero.apellido || ''}`.trim();
    if (obreroSelectedCard && obreroSelectedText) {
        obreroSelectedText.textContent = `${obrero.nombre} ${obrero.apellido || ''} · DNI: ${obrero.documento || 'S/D'} (${obrero.cargo || 'Obrero'})`;
        obreroSelectedCard.classList.remove('hidden');
    }
}

function limpiarSeleccionObrero() {
    obreroHiddenInput.value = '';
    obreroSearchInput.value = '';
    if (obreroSelectedCard) {
        obreroSelectedCard.classList.add('hidden');
    }
}

async function cargarObreros() {
    try {
        ocultarFeedback();
        let obreros = [];
        if (window.chrome?.webview) {
            const data = await sendDesktopRequest("obreros_listar", { page: 1, limit: 100 }, "obreros_listar_response");
            obreros = data.obreros || [];
        } else {
            const response = await fetch('../api/obtener_obrero.php');
            const data = await response.json();
            if (!data.success) {
                throw new Error(data.error || "No se pudo cargar la lista de obreros.");
            }
            obreros = data.obreros || [];
        }

        obrerosList = obreros;
    } catch (error) {
        console.error(error);
        mostrarFeedback('Error cargando la lista de obreros.', 'error');
    }
}

async function buscarConsultas() {
    const idObrero = document.getElementById('obrero').value;
    const fechaDesde = document.getElementById('fecha_desde').value;
    const fechaHasta = document.getElementById('fecha_hasta').value;

    if (!idObrero && !fechaDesde && !fechaHasta) {
        mostrarFeedback('Seleccione al menos un obrero o un período.', 'warning');
        return;
    }

    filtrosActivos = { idObrero, fechaDesde, fechaHasta };
    paginaActual = 1;
    await cargarRegistros();
}

async function cargarRegistros() {
    if (!filtrosActivos) {
        mostrarFeedback('Realice una búsqueda primero.', 'warning');
        return;
    }

    const { idObrero, fechaDesde, fechaHasta } = filtrosActivos;

    try {
        ocultarFeedback();
        let data;

        if (window.chrome?.webview) {
            data = await sendDesktopRequest("consultas_buscar", {
                page: paginaActual,
                limit: ITEMS_POR_PAGINA,
                id_obrero: idObrero || 0,
                fecha_desde: fechaDesde,
                fecha_hasta: fechaHasta
            }, "consultas_buscar_response");
        } else {
            const params = new URLSearchParams({
                page: String(paginaActual),
                limit: String(ITEMS_POR_PAGINA),
                id_obrero: idObrero || '0',
                fecha_desde: fechaDesde,
                fecha_hasta: fechaHasta,
            });

            const response = await fetch(`../api/consultas.php?${params.toString()}`);
            data = await response.json();

            if (!data.success) {
                throw new Error(data.error);
            }
        }

        mostrarResumen(data.resumen || { total_obras: 0, dias_trabajados: 0, total_horas: 0 });
        mostrarRegistros(data.registros || []);

        totalRegistros = Number(data.total || 0);
        totalPaginas = Math.max(1, Number(data.total_pages || 1));
        paginaActual = Math.min(Math.max(1, Number(data.page || paginaActual)), totalPaginas);

        actualizarPaginacion();
    } catch (error) {
        console.error(error);
        mostrarFeedback(error.message || 'Error al buscar consultas.', 'error');
    }
}

function mostrarResumen(resumen) {

    document.getElementById('resumen-consultas').innerHTML = `
        <div class="resumen-card">
            <h3>Obras</h3>
            <span>${resumen.total_obras}</span>
        </div>

        <div class="resumen-card">
            <h3>Días</h3>
            <span>${resumen.dias_trabajados}</span>
        </div>

        <div class="resumen-card">
            <h3>Horas</h3>
            <span>${resumen.total_horas}</span>
        </div>
    `;
}

function mostrarRegistros(registros) {

    const tbody =
        document.getElementById('tabla-registros');

    tbody.innerHTML = '';

    if (registros.length === 0) {

        tbody.innerHTML = `
            <tr>
                <td colspan="5" class="no-data">
                    No se encontraron registros
                </td>
            </tr>
        `;

        return;
    }

    registros.forEach(registro => {

        const fila =
            document.createElement('tr');

        fila.innerHTML = `
            <td>${escapeHtml(registro.fecha)}</td>
            <td>${escapeHtml(registro.obra)}</td>
            <td>${escapeHtml(registro.hora_entrada)}</td>
            <td>${escapeHtml(registro.hora_salida)}</td>
            <td>${escapeHtml(registro.horas_trabajadas)}</td>
        `;

        tbody.appendChild(fila);
    });
}

function actualizarPaginacion() {
    pagination.classList.toggle('hidden', totalRegistros === 0 || totalPaginas === 1);

    const desde = totalRegistros === 0 ? 0 : (paginaActual - 1) * ITEMS_POR_PAGINA + 1;
    const hasta = Math.min(paginaActual * ITEMS_POR_PAGINA, totalRegistros);

    paginationInfo.textContent = `Mostrando ${desde}-${hasta} de ${totalRegistros} ${totalRegistros === 1 ? 'registro' : 'registros'}`;
    paginationPage.textContent = `Página ${paginaActual} de ${totalPaginas}`;
    paginationPrev.disabled = paginaActual === 1;
    paginationNext.disabled = paginaActual === totalPaginas;
}

async function cambiarPagina(direccion) {
    const nuevaPagina = paginaActual + direccion;
    if (nuevaPagina < 1 || nuevaPagina > totalPaginas) {
        return;
    }

    paginaActual = nuevaPagina;
    await cargarRegistros();
}

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
