(function (global) {
    const isDesktop = Boolean(global.chrome?.webview);
    const isBrowserHttp = global.location.protocol.startsWith('http');
    const pendingRequests = new Map();
    let desktopListenerRegistered = false;

    function resolveApiBase() {
        if (!isBrowserHttp) return null;
        const path = global.location.pathname;
        const idx = path.lastIndexOf('/web-ui/');
        if (idx !== -1) {
            return global.location.origin + path.substring(0, idx) + '/api';
        }
        return global.location.origin + '/api';
    }

    const apiBase = resolveApiBase();

    function registerDesktopListener() {
        if (!isDesktop || desktopListenerRegistered) {
            return;
        }

        global.chrome.webview.addEventListener('message', function (event) {
            const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
            const requestId = data?.requestId;

            if (!requestId || !pendingRequests.has(requestId)) {
                return;
            }

            const pending = pendingRequests.get(requestId);
            pendingRequests.delete(requestId);

            if (data.success === false) {
                pending.reject(new Error(data.error || 'No se pudieron cargar los logs.'));
                return;
            }

            pending.resolve(data);
        });

        desktopListenerRegistered = true;
    }

    function nextRequestId(prefix) {
        return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    }

    async function parseJsonResponse(response, fallbackMessage) {
        const text = await response.text();
        if (!text) {
            throw new Error(fallbackMessage);
        }

        try {
            return JSON.parse(text);
        } catch {
            throw new Error(fallbackMessage);
        }
    }

    async function requestBrowser(query) {
        if (!isBrowserHttp) {
            throw new Error('Abrí esta pantalla desde un servidor local PHP para consultar auditoría.');
        }

        const url = new URL(`${apiBase}/auditoria.php`);
        Object.entries(query || {}).forEach(function ([key, value]) {
            if (value !== undefined && value !== null && value !== '') {
                url.searchParams.set(key, String(value));
            }
        });

        const response = await fetch(url, { credentials: 'include' });
        const data = await parseJsonResponse(response, 'No se pudieron cargar los logs.');

        if (!response.ok) {
            throw new Error(data.error || 'No se pudieron cargar los logs.');
        }

        return data;
    }

    function requestDesktop(payload) {
        registerDesktopListener();

        return new Promise(function (resolve, reject) {
            const requestId = nextRequestId('auditoria_listar');
            pendingRequests.set(requestId, { resolve, reject });

            const timeoutId = window.setTimeout(() => {
                pendingRequests.delete(requestId);
                reject(new Error('La aplicación de escritorio no respondió a tiempo.'));
            }, 15000);

            const originalResolve = resolve;
            const originalReject = reject;
            pendingRequests.set(requestId, {
                resolve: (data) => { window.clearTimeout(timeoutId); originalResolve(data); },
                reject: (err) => { window.clearTimeout(timeoutId); originalReject(err); }
            });

            global.chrome.webview.postMessage(JSON.stringify({
                type: 'auditoria_listar',
                requestId,
                ...(payload || {})
            }));
        });
    }

    global.auditApi = {
        listLogs: function (query) {
            return isDesktop ? requestDesktop(query) : requestBrowser(query);
        }
    };
})(window);

document.addEventListener('DOMContentLoaded', function () {
    const form = document.getElementById('filtersForm');
    const usuarioEl = document.getElementById('filterUsuario');
    const accionEl = document.getElementById('filterAccion');
    const entidadEl = document.getElementById('filterEntidad');
    const fechaDesdeEl = document.getElementById('filterFechaDesde');
    const fechaHastaEl = document.getElementById('filterFechaHasta');
    const resetBtn = document.getElementById('btnReset');
    const tbody = document.getElementById('logsBody');
    const feedbackEl = document.getElementById('feedback');
    const summaryEl = document.getElementById('summaryText');
    const pageInfoEl = document.getElementById('pageInfo');
    const prevBtn = document.getElementById('btnPrev');
    const nextBtn = document.getElementById('btnNext');

    const state = { page: 1, totalPages: 1, filtersLoaded: false };

    form.addEventListener('submit', function (event) {
        event.preventDefault();
        state.page = 1;
        loadLogs();
    });

    resetBtn.addEventListener('click', function () {
        form.reset();
        state.page = 1;
        loadLogs();
    });

    prevBtn.addEventListener('click', function () {
        if (state.page > 1) {
            state.page -= 1;
            loadLogs();
        }
    });

    nextBtn.addEventListener('click', function () {
        if (state.page < state.totalPages) {
            state.page += 1;
            loadLogs();
        }
    });

    loadLogs();

    async function loadLogs() {
        tbody.innerHTML = '<tr><td colspan="8" class="table-status">Cargando logs...</td></tr>';
        hideFeedback();

        try {
            const data = await window.auditApi.listLogs({
                page: state.page,
                limit: 20,
                usuario: usuarioEl.value.trim(),
                accion: accionEl.value,
                entidad: entidadEl.value,
                fecha_desde: fechaDesdeEl.value,
                fecha_hasta: fechaHastaEl.value
            });

            state.totalPages = Number(data.total_pages || 1);
            renderFilters(data.filters || {});
            renderLogs(data.logs || []);
            summaryEl.textContent = `Mostrando ${data.logs?.length || 0} de ${data.total || 0} registros`;
            pageInfoEl.textContent = `Página ${data.page || 1} de ${data.total_pages || 1}`;
            prevBtn.disabled = (data.page || 1) <= 1;
            nextBtn.disabled = (data.page || 1) >= (data.total_pages || 1);
        } catch (error) {
            tbody.innerHTML = `<tr><td colspan="8" class="table-status">${escapeHtml(error.message || 'No se pudieron cargar los logs.')}</td></tr>`;
            summaryEl.textContent = 'Sin datos disponibles';
            pageInfoEl.textContent = 'Página 1 de 1';
            prevBtn.disabled = true;
            nextBtn.disabled = true;
            showFeedback(error.message || 'No se pudieron cargar los logs.', 'error');
        }
    }

    function renderFilters(filters) {
        if (!state.filtersLoaded) {
            fillSelect(accionEl, filters.acciones || []);
            fillSelect(entidadEl, filters.entidades || []);
            state.filtersLoaded = true;
        }
    }

    function fillSelect(select, values) {
        const currentValue = select.value;
        select.innerHTML = '<option value="">Todas</option>';
        values.forEach(function (value) {
            const option = document.createElement('option');
            option.value = value;
            option.textContent = select === accionEl ? getActionLabel(value) : getEntityLabel(value);
            select.appendChild(option);
        });
        select.value = currentValue;
    }

    function renderLogs(logs) {
        if (!Array.isArray(logs) || logs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" class="table-status">No hay registros para los filtros seleccionados.</td></tr>';
            return;
        }

        tbody.innerHTML = logs.map(function (log) {
            return `
                <tr>
                    <td>${escapeHtml(formatDateTime(log.created_at))}</td>
                    <td>${escapeHtml(log.usuario || '-')}</td>
                    <td>${escapeHtml(log.rol || '-')}</td>
                    <td><span class="pill">${escapeHtml(getActionLabel(log.accion))}</span></td>
                    <td>${escapeHtml(getEntityLabel(log.entidad))}</td>
                    <td>${log.entidad_id ?? '-'}</td>
                    <td>${escapeHtml(formatOrigin(log.ip_address))}</td>
                    <td class="detail-cell">${escapeHtml(formatDetail(log))}</td>
                </tr>`;
        }).join('');
    }

    function formatDetail(log) {
        const detail = log?.detalle;
        const action = log?.accion || '';
        const entity = log?.entidad || '';

        if (!detail || typeof detail !== 'object') {
            const fallback = buildFallbackSummary(action, entity, log?.entidad_id);
            return fallback || '-';
        }

        const summary = buildSummary(action, entity, detail, log?.entidad_id);
        if (summary) {
            return summary;
        }

        return Object.entries(detail).map(function ([key, value]) {
            return `${getDetailLabel(key)}: ${formatValue(value)}`;
        }).join(' | ');
    }

    function buildSummary(action, entity, detail, entityId) {
        if (entity === 'usuarios') {
            const usuario = detail.usuario ? `usuario ${detail.usuario}` : `usuario #${entityId ?? '-'}`;
            if (action === 'crear') return `Se creó el ${usuario}.`;
            if (action === 'editar') return `Se actualizó el ${usuario}${detail.password_actualizada ? ' y se cambió la contraseña' : ''}.`;
            if (action === 'eliminar') return `Se eliminó el ${usuario}.`;
        }

        if (entity === 'obras') {
            const nombre = detail.nombre || `obra #${entityId ?? '-'}`;
            const contrata = detail.numero_contrata ? ` (contrata ${detail.numero_contrata})` : '';
            if (action === 'crear') return `Se registró ${nombre}${contrata}.`;
            if (action === 'editar') return `Se actualizó ${nombre}${detail.contrato_actualizado ? ' y se reemplazó el contrato' : ''}.`;
            if (action === 'eliminar') return `Se eliminó ${nombre}${contrata}.`;
            if (action === 'cambiar_estado') return `${nombre} quedó ${Number(detail.activo) === 1 ? 'activa' : 'inactiva'}.`;
        }

        if (entity === 'obreros') {
            const nombreCompleto = [detail.nombre, detail.apellido].filter(Boolean).join(' ') || `obrero #${entityId ?? '-'}`;
            if (action === 'crear') return `Se registró a ${nombreCompleto}.`;
            if (action === 'editar') return `Se actualizó a ${nombreCompleto}.`;
            if (action === 'eliminar') return `Se dio de baja a ${nombreCompleto}.`;
        }

        if (entity === 'contrato_obrero' && action === 'subir_contrato') {
            return `Se subió el contrato ${detail.archivo || ''}${detail.fecha_vencimiento ? ` con vencimiento ${detail.fecha_vencimiento}` : ''}.`.trim();
        }

        if (entity === 'maquinaria') {
            const nombre = detail.nombre || `maquinaria #${entityId ?? '-'}`;
            if (action === 'crear') return `Se registró ${nombre}.`;
            if (action === 'editar') return `Se actualizó ${nombre}.`;
            if (action === 'eliminar') return `Se eliminó ${nombre}.`;
        }

        if (entity === 'certificados_maquinaria') {
            if (action === 'subir_certificado') return `Se subió el certificado ${detail.archivo || ''} para la maquinaria #${detail.id_maquinaria ?? entityId ?? '-'}.`.trim();
            if (action === 'eliminar_certificado') return `Se eliminó un certificado de maquinaria.`;
        }

        if (entity === 'asistencia' && action === 'guardar') {
            return `Se guardó asistencia de la obra #${detail.id_obra ?? entityId ?? '-'} para ${detail.fecha || 'sin fecha'}: ${detail.obreros ?? 0} obreros, ${detail.materiales ?? detail.recursos ?? 0} recursos y ${detail.maquinarias ?? 0} máquinas.`;
        }

        if (entity === 'auth') {
            if (action === 'login') return 'Inicio de sesión exitoso.';
            if (action === 'logout') return 'Cierre de sesión.';
        }

        return '';
    }

    function buildFallbackSummary(action, entity, entityId) {
        const actionLabel = getActionLabel(action).toLowerCase();
        const entityLabel = getEntityLabel(entity).toLowerCase();
        if (!actionLabel || !entityLabel) {
            return '';
        }

        return `${actionLabel} sobre ${entityLabel}${entityId ? ` #${entityId}` : ''}.`;
    }

    function getActionLabel(action) {
        const labels = {
            login: 'Inicio de sesion',
            logout: 'Cierre de sesion',
            crear: 'Alta',
            editar: 'Edicion',
            eliminar: 'Baja',
            cambiar_estado: 'Cambio de estado',
            subir_contrato: 'Carga de contrato',
            subir_certificado: 'Carga de certificado',
            eliminar_certificado: 'Baja de certificado',
            guardar: 'Guardado'
        };

        return labels[action] || humanizeToken(action);
    }

    function getEntityLabel(entity) {
        const labels = {
            auth: 'Sesion',
            usuarios: 'Usuarios',
            obras: 'Obras',
            obreros: 'Obreros',
            contrato_obrero: 'Contratos de obreros',
            maquinaria: 'Maquinaria',
            certificados_maquinaria: 'Certificados de maquinaria',
            asistencia: 'Asistencia'
        };

        return labels[entity] || humanizeToken(entity);
    }

    function getDetailLabel(key) {
        const labels = {
            numero_contrata: 'Contrata',
            nombre: 'Nombre',
            apellido: 'Apellido',
            usuario: 'Usuario',
            rol: 'Rol',
            archivo: 'Archivo',
            fecha_vencimiento: 'Vencimiento',
            fecha: 'Fecha',
            id_obra: 'Obra',
            id_maquinaria: 'Maquinaria',
            password_actualizada: 'Cambio de contraseña',
            contrato_actualizado: 'Contrato reemplazado',
            contrato_cargado: 'Contrato cargado',
            activo: 'Estado',
            obreros: 'Obreros',
            materiales: 'Materiales',
            recursos: 'Recursos',
            maquinarias: 'Máquinas',
            finaliza_obra: 'Finaliza obra',
            resultado: 'Resultado',
            marca: 'Marca',
            documento: 'Documento'
        };

        return labels[key] || humanizeToken(key);
    }

    function formatValue(value) {
        if (typeof value === 'boolean') {
            return value ? 'Sí' : 'No';
        }

        if (value === 1 || value === '1') {
            return 'Sí';
        }

        if (value === 0 || value === '0') {
            return 'No';
        }

        return String(value);
    }

    function formatOrigin(value) {
        if (!value) return '-';
        if (value === '::1' || value === '127.0.0.1') return 'localhost';
        if (value === 'desktop') return 'Aplicación desktop';
        return value;
    }

    function humanizeToken(value) {
        return String(value || '')
            .replace(/_/g, ' ')
            .replace(/\b\w/g, function (letter) { return letter.toUpperCase(); });
    }

    function formatDateTime(value) {
        if (!value) return '-';
        const date = new Date(String(value).replace(' ', 'T'));
        if (Number.isNaN(date.getTime())) {
            return String(value);
        }

        return new Intl.DateTimeFormat('es-AR', { dateStyle: 'short', timeStyle: 'short' }).format(date);
    }

    function showFeedback(message, type) {
        feedbackEl.hidden = false;
        feedbackEl.textContent = message;
        feedbackEl.className = `feedback feedback-${type}`;
    }

    function hideFeedback() {
        feedbackEl.hidden = true;
        feedbackEl.textContent = '';
        feedbackEl.className = 'feedback';
    }

    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }
});