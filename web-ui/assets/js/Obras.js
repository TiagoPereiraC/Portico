const obraForm = document.getElementById('obraForm');
const formTitle = document.getElementById('formTitle');
const btnGuardar = document.getElementById('btnGuardar');
const btnBack = document.querySelector('.btn-back');
const contratoInput = document.getElementById('contrato_archivo');
const contratoEstado = document.getElementById('contratoEstado');
const obrasTableBody = document.getElementById('obrasTableBody');
const resultsCount = document.getElementById('resultsCount');
const tableWrap = document.getElementById('tableWrap');
const loadingState = document.getElementById('loadingState');
const emptyState = document.getElementById('emptyState');
const feedbackPanel = document.getElementById('feedbackPanel');
const feedbackTitle = document.getElementById('feedbackTitle');
const feedbackMessage = document.getElementById('feedbackMessage');
const feedbackClose = document.getElementById('feedbackClose');
const confirmModal = document.getElementById('confirmModal');
const confirmTitle = document.getElementById('confirmTitle');
const confirmMessage = document.getElementById('confirmMessage');
const confirmCancel = document.getElementById('confirmCancel');
const confirmAccept = document.getElementById('confirmAccept');
const isDesktopWebView = Boolean(window.chrome?.webview);
const apiBase = window.location.protocol.startsWith('http') ? `${window.location.origin}/api` : null;
const MAX_CONTRATO_SIZE = 10 * 1024 * 1024;

let csrfToken = '';
let obras = [];
let obraEnEdicion = null;
let confirmAction = null;

feedbackClose.addEventListener('click', ocultarFeedback);
contratoInput.addEventListener('change', actualizarEstadoContratoSeleccionado);
btnBack.addEventListener('click', (event) => {
  if (obraEnEdicion === null) {
    return;
  }

  event.preventDefault();
  resetForm();
  setFeedback('Edición cancelada.', 'info');
});
confirmCancel.addEventListener('click', cerrarConfirmacion);
confirmAccept.addEventListener('click', async () => {
  if (!confirmAction) {
    cerrarConfirmacion();
    return;
  }

  confirmAccept.disabled = true;

  try {
    await confirmAction();
  } finally {
    confirmAccept.disabled = false;
    cerrarConfirmacion();
  }
});
confirmModal.addEventListener('click', (event) => {
  if (event.target === confirmModal) {
    cerrarConfirmacion();
  }
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && !confirmModal.classList.contains('hidden')) {
    cerrarConfirmacion();
  }
});

obraForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const payload = await buildPayload();
  if (!payload) {
    return;
  }

  btnGuardar.disabled = true;
  btnGuardar.textContent = obraEnEdicion ? 'Actualizando...' : 'Guardando...';

  try {
    if (apiBase && !csrfToken) {
      csrfToken = await obtenerCsrf();
    }

    const data = await guardarObra(payload);
    upsertObra(data.obra);
    renderObras();
    setFeedback(data.message || 'Obra guardada correctamente.', 'success');
    resetForm();
  } catch (error) {
    console.error(error);
    setFeedback(error.message || 'No se pudo guardar la obra.', 'error');
  } finally {
    btnGuardar.disabled = false;
    btnGuardar.textContent = 'Guardar';
  }
});

document.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) {
    return;
  }

  const idObra = Number.parseInt(button.dataset.id, 10);
  if (!idObra) {
    return;
  }

  if (button.dataset.action === 'edit') {
    const obra = obras.find((item) => item.id_obra === idObra);
    if (obra) {
      abrirConfirmacion({
        title: 'Confirmar edición',
        message: `¿Querés cargar "${obra.nombre}" en el formulario para editarla?`,
        acceptLabel: 'Editar',
        onAccept: async () => {
          fillForm(obra);
          setFeedback(`Editando ${obra.nombre}.`, 'info');
        }
      });
    }
    return;
  }

  if (button.dataset.action === 'download') {
    try {
      await descargarContrato(idObra);
    } catch (error) {
      console.error(error);
      setFeedback(error.message || 'No se pudo descargar el contrato.', 'error');
    }
    return;
  }

  if (button.dataset.action === 'delete') {
    const obra = obras.find((item) => item.id_obra === idObra);
    if (!obra) {
      return;
    }

    abrirConfirmacion({
      title: 'Confirmar eliminación',
      message: `¿Eliminar la obra "${obra.nombre}"? Esta acción no se puede deshacer.`,
      acceptLabel: 'Eliminar',
      onAccept: async () => {
        try {
          if (apiBase && !csrfToken) {
            csrfToken = await obtenerCsrf();
          }

          const data = await eliminarObra(idObra);
          obras = obras.filter((item) => item.id_obra !== idObra);
          renderObras();
          if (obraEnEdicion === idObra) {
            resetForm();
          }
          setFeedback(data.message || 'Obra eliminada correctamente.', 'success');
        } catch (error) {
          console.error(error);
          setFeedback(error.message || 'No se pudo eliminar la obra.', 'error');
        }
      }
    });
  }
});

inicializarVista().catch((error) => {
  console.error(error);
  setFeedback(error.message || 'No se pudieron cargar las obras.', 'error');
});

async function inicializarVista() {
  setLoading(true);

  if (!apiBase && !isDesktopWebView) {
    setLoading(false);
    throw new Error('Abrí esta pantalla desde navegador con PHP o desde la app de escritorio.');
  }

  try {
    if (apiBase) {
      const [token, data] = await Promise.all([
        obtenerCsrf(),
        fetchJson(`${apiBase}/Obras.php`)
      ]);
      csrfToken = token;
      obras = data.obras || [];
    } else {
      const data = await sendDesktopRequest('obras_listar', {}, 'obras_listar_response');
      obras = data.obras || [];
    }

    renderObras();
  } finally {
    setLoading(false);
  }
}

async function buildPayload() {
  const payload = {
    id_obra: leerCampo('id_obra') || undefined,
    numero_contrata: leerCampo('numero_contrata'),
    nombre: leerCampo('nombre'),
    direccion: leerCampo('direccion'),
    descripcion: leerCampo('descripcion'),
    fecha_inicio: leerCampo('fecha_inicio'),
    fecha_fin: obraEnEdicion ? (obras.find((item) => item.id_obra === obraEnEdicion)?.fecha_fin || '') : '',
    nombre_cliente: leerCampo('nombre_cliente'),
    telefono_cliente: leerCampo('telefono_cliente')
  };

  if (!payload.numero_contrata || !payload.nombre || !payload.nombre_cliente) {
    setFeedback('Número de contrata, nombre de la obra y cliente son obligatorios.', 'error');
    return null;
  }

  if (payload.fecha_inicio && payload.fecha_fin && payload.fecha_fin < payload.fecha_inicio) {
    setFeedback('La fecha de fin no puede ser menor a la de inicio.', 'error');
    return null;
  }

  const contrato = await leerContratoSeleccionado();
  if (contrato === false) {
    return null;
  }

  if (contrato) {
    payload.contrato = contrato;
  }

  return payload;
}

function leerCampo(id) {
  return document.getElementById(id).value.trim();
}

async function guardarObra(payload) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      credentials: 'include',
      body: JSON.stringify(payload)
    });

    const data = await parseJsonResponse(response, 'No se pudo guardar la obra.');
    if (!response.ok) {
      throw new Error(data.error || 'No se pudo guardar la obra.');
    }

    return data;
  }

  return sendDesktopRequest('obras_guardar', payload, 'obras_guardar_response');
}

async function eliminarObra(idObra) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      credentials: 'include',
      body: JSON.stringify({ id_obra: idObra })
    });

    const data = await parseJsonResponse(response, 'No se pudo eliminar la obra.');
    if (!response.ok) {
      throw new Error(data.error || 'No se pudo eliminar la obra.');
    }

    return data;
  }

  return sendDesktopRequest('obras_eliminar', { id_obra: idObra }, 'obras_eliminar_response');
}

async function descargarContrato(idObra) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php?id_obra=${encodeURIComponent(idObra)}&descargar_contrato=1`, {
      credentials: 'include'
    });

    if (!response.ok) {
      const text = await response.text();
      try {
        const data = JSON.parse(text);
        throw new Error(data.error || 'No se pudo descargar el contrato.');
      } catch {
        throw new Error('No se pudo descargar el contrato.');
      }
    }

    const blob = await response.blob();
    const nombreArchivo = getFileNameFromDisposition(response.headers.get('Content-Disposition'))
      || obras.find((item) => item.id_obra === idObra)?.contrato_nombre_archivo
      || `contrato-${idObra}`;
    triggerBrowserDownload(blob, nombreArchivo);
    return;
  }

  const data = await sendDesktopRequest('obras_descargar_contrato', { id_obra: idObra }, 'obras_descargar_contrato_response');
  if (!data.contenido_base64 || !data.nombre_archivo) {
    throw new Error('No se pudo descargar el contrato.');
  }

  const blob = base64ToBlob(data.contenido_base64, data.tipo_contenido || 'application/octet-stream');
  triggerBrowserDownload(blob, data.nombre_archivo);
}

function sendDesktopRequest(type, payload, responseType) {
  if (!isDesktopWebView) {
    return Promise.reject(new Error('El puente de escritorio no está disponible.'));
  }

  const requestId = `${type}-${Date.now()}-${Math.random().toString(36).slice(2)}`;

  return new Promise((resolve, reject) => {
    const timeoutId = window.setTimeout(() => {
      window.chrome.webview.removeEventListener('message', onMessage);
      reject(new Error('La aplicación de escritorio no respondió a tiempo.'));
    }, 15000);

    function onMessage(event) {
      const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      if (data.type !== responseType || data.requestId !== requestId) {
        return;
      }

      window.clearTimeout(timeoutId);
      window.chrome.webview.removeEventListener('message', onMessage);

      if (!data.success) {
        reject(new Error(data.error || 'Error de escritorio.'));
        return;
      }

      resolve(data);
    }

    window.chrome.webview.addEventListener('message', onMessage);
    window.chrome.webview.postMessage(JSON.stringify({ type, requestId, ...payload }));
  });
}

async function fetchJson(url, options) {
  const response = await fetch(url, {
    credentials: 'include',
    ...options
  });
  const data = await parseJsonResponse(response, 'Error de servidor.');

  if (!response.ok) {
    throw new Error(data.error || 'Error de servidor.');
  }

  return data;
}

async function obtenerCsrf() {
  const data = await fetchJson(`${apiBase}/csrf.php`);
  return data.token || '';
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

function renderObras() {
  obrasTableBody.innerHTML = '';
  const sorted = [...obras].sort((a, b) => (b.fecha_inicio || '').localeCompare(a.fecha_inicio || '') || a.nombre.localeCompare(b.nombre));

  resultsCount.textContent = `${sorted.length} ${sorted.length === 1 ? 'obra' : 'obras'}`;
  tableWrap.classList.toggle('hidden', sorted.length === 0);
  emptyState.classList.toggle('hidden', sorted.length !== 0);

  sorted.forEach((obra) => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${escapeHtml(obra.numero_contrata)}</td>
      <td>
        <strong>${escapeHtml(obra.nombre)}</strong>
        <span class="table-subline">${escapeHtml(obra.direccion || 'Sin dirección cargada')}</span>
        <span class="table-subline">${escapeHtml(obra.contrato_nombre_archivo ? `Contrato: ${obra.contrato_nombre_archivo}` : 'Sin contrato cargado')}</span>
      </td>
      <td>${escapeHtml(obra.nombre_cliente)}</td>
      <td>${formatDate(obra.fecha_inicio)}</td>
      <td>${formatDate(obra.fecha_fin)}</td>
      <td>
        <div class="table-actions">
          <button type="button" class="action-btn download" data-action="download" data-id="${obra.id_obra}" ${obra.contrato_nombre_archivo ? '' : 'disabled'} title="Descargar contrato">
            <i class="fas fa-download"></i>
          </button>
          <button type="button" class="action-btn edit" data-action="edit" data-id="${obra.id_obra}">
            <i class="fas fa-pen"></i>
          </button>
          <button type="button" class="action-btn delete" data-action="delete" data-id="${obra.id_obra}">
            <i class="fas fa-trash"></i>
          </button>
        </div>
      </td>
    `;
    obrasTableBody.appendChild(row);
  });
}

function setLoading(isLoading) {
  loadingState.classList.toggle('hidden', !isLoading);
  if (isLoading) {
    tableWrap.classList.add('hidden');
    emptyState.classList.add('hidden');
  }
}

function upsertObra(obra) {
  const index = obras.findIndex((item) => item.id_obra === obra.id_obra);
  if (index >= 0) {
    obras[index] = obra;
    return;
  }
  obras.push(obra);
}

function fillForm(obra) {
  obraEnEdicion = obra.id_obra;
  document.getElementById('id_obra').value = obra.id_obra;
  document.getElementById('numero_contrata').value = obra.numero_contrata || '';
  document.getElementById('nombre').value = obra.nombre || '';
  document.getElementById('direccion').value = obra.direccion || '';
  document.getElementById('descripcion').value = obra.descripcion || '';
  document.getElementById('fecha_inicio').value = obra.fecha_inicio || '';
  document.getElementById('nombre_cliente').value = obra.nombre_cliente || '';
  document.getElementById('telefono_cliente').value = obra.telefono_cliente || '';
  contratoInput.value = '';
  actualizarEstadoContratoActual(obra.contrato_nombre_archivo || '');
  formTitle.textContent = 'Editar obra';
  btnGuardar.textContent = 'Guardar';
  btnBack.textContent = 'Cancelar edición';
}

function resetForm() {
  obraForm.reset();
  obraEnEdicion = null;
  document.getElementById('id_obra').value = '';
  contratoInput.value = '';
  actualizarEstadoContratoActual('');
  formTitle.textContent = 'Nueva obra';
  btnBack.textContent = 'Volver';
}

async function leerContratoSeleccionado() {
  const file = contratoInput.files?.[0];
  if (!file) {
    return null;
  }

  if (file.size > MAX_CONTRATO_SIZE) {
    setFeedback('El contrato no puede superar los 10 MB.', 'error');
    return false;
  }

  if (file.name.length > 255) {
    setFeedback('El nombre del archivo es demasiado largo.', 'error');
    return false;
  }

  try {
    const dataUrl = await readFileAsDataUrl(file);
    const commaIndex = dataUrl.indexOf(',');
    if (commaIndex === -1) {
      throw new Error('Formato de archivo inválido.');
    }

    return {
      nombre_archivo: file.name,
      tipo_contenido: file.type || 'application/octet-stream',
      contenido_base64: dataUrl.slice(commaIndex + 1)
    };
  } catch (error) {
    setFeedback(error.message || 'No se pudo leer el contrato seleccionado.', 'error');
    return false;
  }
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(new Error('No se pudo leer el contrato seleccionado.'));
    reader.readAsDataURL(file);
  });
}

function actualizarEstadoContratoSeleccionado() {
  const file = contratoInput.files?.[0];
  if (file) {
    contratoEstado.textContent = `Archivo seleccionado: ${file.name}`;
    return;
  }

  const obraActual = obras.find((item) => item.id_obra === obraEnEdicion);
  actualizarEstadoContratoActual(obraActual?.contrato_nombre_archivo || '');
}

function actualizarEstadoContratoActual(nombreArchivo) {
  contratoEstado.textContent = nombreArchivo
    ? `Contrato actual: ${nombreArchivo}`
    : 'Sin contrato cargado.';
}

function triggerBrowserDownload(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function base64ToBlob(base64, mimeType) {
  const binary = window.atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return new Blob([bytes], { type: mimeType });
}

function getFileNameFromDisposition(disposition) {
  if (!disposition) {
    return '';
  }

  const utfMatch = disposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utfMatch?.[1]) {
    return decodeURIComponent(utfMatch[1]);
  }

  const match = disposition.match(/filename="?([^";]+)"?/i);
  return match?.[1] || '';
}

function setFeedback(message, type = 'info') {
  feedbackPanel.classList.remove('hidden', 'feedback-success', 'feedback-error', 'feedback-info');
  feedbackPanel.classList.add(`feedback-${type}`);
  feedbackTitle.textContent = type === 'error' ? 'No se pudo completar la acción' : type === 'success' ? 'Operación completada' : 'Atención';
  feedbackMessage.textContent = message;
}

function abrirConfirmacion({ title, message, acceptLabel, onAccept }) {
  confirmTitle.textContent = title;
  confirmMessage.textContent = message;
  confirmAccept.textContent = acceptLabel;
  confirmAction = onAccept;
  confirmModal.classList.remove('hidden');
}

function cerrarConfirmacion() {
  confirmModal.classList.add('hidden');
  confirmAction = null;
  confirmAccept.textContent = 'Confirmar';
}

function ocultarFeedback() {
  feedbackPanel.classList.add('hidden');
}

function formatDate(value) {
  if (!value) {
    return 'Sin fecha';
  }

  const [year, month, day] = value.split('-');
  if (!year || !month || !day) {
    return value;
  }

  return `${day}/${month}/${year}`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
