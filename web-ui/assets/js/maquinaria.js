const panelListado = document.getElementById("panelListado");
const panelFormulario = document.getElementById("panelFormulario");
const openFormPanel = document.getElementById("openFormPanel");
const cancelFormPanel = document.getElementById("cancelFormPanel");
const maquinariaForm = document.getElementById("maquinariaForm");
const formTitle = document.getElementById("formTitle");
const btnGuardar = document.getElementById("btnGuardar");
const maquinariaTableBody = document.getElementById("maquinariaTableBody");
const searchMaquinaria = document.getElementById("searchMaquinaria");
const tableWrap = document.getElementById("tableWrap");
const loadingState = document.getElementById("loadingState");
const emptyState = document.getElementById("emptyState");
const emptyStateMessage = document.getElementById("emptyStateMessage");
const resultsCount = document.getElementById("resultsCount");
const pagination = document.getElementById("pagination");
const paginationInfo = document.getElementById("paginationInfo");
const paginationPage = document.getElementById("paginationPage");
const paginationPrev = document.getElementById("paginationPrev");
const paginationNext = document.getElementById("paginationNext");
const feedbackPanel = document.getElementById("feedbackPanel");
const feedbackTitle = document.getElementById("feedbackTitle");
const feedbackMessage = document.getElementById("feedbackMessage");
const feedbackClose = document.getElementById("feedbackClose");
const confirmModal = document.getElementById("confirmModal");
const confirmTitle = document.getElementById("confirmTitle");
const confirmMessage = document.getElementById("confirmMessage");
const confirmCancel = document.getElementById("confirmCancel");
const confirmAccept = document.getElementById("confirmAccept");
const certModal = document.getElementById("certModal");
const certModalTitle = document.getElementById("certModalTitle");
const certArchivo = document.getElementById("certArchivo");
const certVencimiento = document.getElementById("certVencimiento");
const certSubirBtn = document.getElementById("certSubirBtn");
const certCancelarBtn = document.getElementById("certCancelarBtn");
const certLista = document.getElementById("certLista");
const certListaWrap = document.getElementById("certListaWrap");
const alertasVencimiento = document.getElementById("alertasVencimiento");
const alertasLista = document.getElementById("alertasLista");
const alertasCerrar = document.getElementById("alertasCerrar");
const certSection = document.getElementById("certSection");
const certArchivoForm = document.getElementById("certArchivoForm");
const certVencimientoForm = document.getElementById("certVencimientoForm");
const certListaForm = document.getElementById("certListaForm");

// Nuevo: filtro de certificados vencidos/por vencer
const filtroCertCheckbox = document.getElementById("filtroCertificados");
let filtroCertActivo = false;

const MAX_CERTIFICADO_SIZE = 10 * 1024 * 1024; // 10 MB

function validarArchivoCertificado(file) {
  if (!file) {
    throw new Error("Seleccioná un archivo primero.");
  }
  if (file.size > MAX_CERTIFICADO_SIZE) {
    const sizeMb = (file.size / (1024 * 1024)).toFixed(2);
    throw new Error(`El certificado seleccionado (${sizeMb} MB) supera el tamaño máximo permitido (10 MB).`);
  }
  const ext = (file.name.split(".").pop() || "").toLowerCase();
  const permitidas = ["pdf", "doc", "docx", "jpg", "jpeg", "png"];
  if (!permitidas.includes(ext)) {
    throw new Error("Formato de archivo no permitido. Solo se aceptan PDF, DOC, DOCX, JPG o PNG.");
  }
  return true;
}

const isDesktopWebView = Boolean(window.chrome?.webview);

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

const apiBase = resolveApiBase();
const ITEMS_POR_PAGINA = 10;

let csrfToken = "";
let maquinaria = [];
let totalItems = 0;
let totalPaginas = 1;
let itemEnEdicion = null;
let confirmAction = null;
let paginaActual = 1;
let terminoBusqueda = "";
let busquedaTimeoutId = null;
let ultimaSolicitudListado = 0;

feedbackClose.addEventListener("click", ocultarFeedback);
confirmCancel.addEventListener("click", cerrarConfirmacion);
confirmAccept.addEventListener("click", async () => {
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
confirmModal.addEventListener("click", (event) => {
  if (event.target === confirmModal) {
    cerrarConfirmacion();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !confirmModal.classList.contains("hidden")) {
    cerrarConfirmacion();
  }
});
paginationPrev.addEventListener("click", () => cambiarPagina(-1));
paginationNext.addEventListener("click", () => cambiarPagina(1));

certCancelarBtn.addEventListener("click", cerrarCertModal);
alertasCerrar.addEventListener("click", () => {
  alertasVencimiento.classList.add("hidden");
});

certSubirBtn.addEventListener("click", async () => {
  if (!certModal.dataset.idMaquinaria) return;
  const file = certArchivo.files[0];
  if (!file) {
    setFeedback("Seleccioná un archivo primero.", "error");
    return;
  }
  try {
    validarArchivoCertificado(file);
  } catch (validationError) {
    setFeedback(validationError.message, "error");
    return;
  }
  certSubirBtn.disabled = true;
  try {
    await subirCertificado(Number(certModal.dataset.idMaquinaria), file, certVencimiento.value);
    certArchivo.value = "";
    certVencimiento.value = "";
    await cargarCertificados(Number(certModal.dataset.idMaquinaria));
    setFeedback("Certificado subido correctamente.", "success");
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo subir el certificado.", "error");
  } finally {
    certSubirBtn.disabled = false;
  }
});
certModal.addEventListener("click", (event) => {
  if (event.target === certModal) cerrarCertModal();
});

openFormPanel.addEventListener("click", () => {
  resetForm();
  togglePanels(true);
});
cancelFormPanel.addEventListener("click", () => {
  if (itemEnEdicion === null) {
    togglePanels(false);
    return;
  }
  resetForm();
  togglePanels(false);
  setFeedback("Edición cancelada.", "info");
});

maquinariaForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const payload = buildPayload();
    if (!payload) return;

    const archivo = certArchivoForm.files[0];
    if (archivo) {
        try {
            validarArchivoCertificado(archivo);
        } catch (validationError) {
            setFeedback(validationError.message, "error");
            return;
        }
    }

    btnGuardar.disabled = true;
    btnGuardar.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + (itemEnEdicion ? "Actualizando maquinaria..." : "Guardando maquinaria...");

    try {

        if (apiBase && !csrfToken) {
            csrfToken = await obtenerCsrf();
        }

        // =============================
        // Guardar maquinaria
        // =============================
        const data = await guardarMaquinaria(payload);

        const idMaquinaria =
            Number(data.maquinaria?.id_maquinaria) ||
            Number(payload.id_maquinaria) ||
            Number(itemEnEdicion);

        const fechaForm = certVencimientoForm.value ? certVencimientoForm.value.substring(0, 10) : "";

        // =============================
        // Si se seleccionó un certificado,
        // subirlo automáticamente
        // =============================
        if (archivo && idMaquinaria > 0) {

            await subirCertificado(
                idMaquinaria,
                archivo,
                fechaForm
            );

        } else if (idMaquinaria > 0 && certVencimientoForm.dataset.ultimoCertId) {
            // No se subió un nuevo archivo pero se cambió la fecha de vencimiento de un certificado existente
            const idCertExistente = Number(certVencimientoForm.dataset.ultimoCertId);
            const fechaOriginal = certVencimientoForm.dataset.fechaOriginal || "";
            if (idCertExistente > 0 && fechaForm !== fechaOriginal) {
                await editarFechaCertificado(idCertExistente, fechaForm || null);
            }
        }

        paginaActual = 1;

        await cargarMaquinaria();

        const mensajeExito = archivo
            ? "Maquinaria y certificado guardados correctamente."
            : (data.message || "Maquinaria guardada correctamente.");

        setFeedback(mensajeExito, "success");

        resetForm();

        togglePanels(false);

    } catch (error) {

        console.error(error);

        setFeedback(
            error.message || "No se pudo guardar la maquinaria.",
            "error"
        );

    } finally {

        btnGuardar.disabled = false;
        btnGuardar.innerHTML = '<i class="fas fa-floppy-disk"></i> ' + (itemEnEdicion ? "Guardar cambios" : "Guardar maquinaria");

    }

});

searchMaquinaria.addEventListener("input", (event) => {
  terminoBusqueda = event.target.value || "";
  paginaActual = 1;
  window.clearTimeout(busquedaTimeoutId);
  busquedaTimeoutId = window.setTimeout(() => {
    cargarMaquinaria().catch((error) => {
      console.error(error);
      setFeedback(error.message || "No se pudo cargar la maquinaria.", "error");
    });
  }, 200);
});

// Nuevo: evento del filtro de certificados
filtroCertCheckbox.addEventListener("change", (e) => {
  filtroCertActivo = e.target.checked;
  paginaActual = 1;
  terminoBusqueda = searchMaquinaria.value;
  cargarMaquinaria().catch((error) => {
    console.error(error);
    setFeedback(error.message || "No se pudo aplicar el filtro.", "error");
  });
});



inicializarVista().catch((error) => {
  console.error(error);
  setFeedback(error.message || "No se pudo cargar la maquinaria.", "error");
});

async function inicializarVista() {
  setLoading(true);

  if (!apiBase && !isDesktopWebView) {
    setLoading(false);
    throw new Error(
      "Abrí esta pantalla desde navegador con PHP o desde la app de escritorio.",
    );
  }

  try {
    if (apiBase) {
      csrfToken = await obtenerCsrf();
    }
    await cargarMaquinaria();
    if (apiBase) {
      cargarAlertas().catch(err => console.error('Error cargando alertas:', err));
    }
  } finally {
    setLoading(false);
  }
}

function togglePanels(showForm) {
  panelListado.classList.toggle("hidden", showForm);
  panelFormulario.classList.toggle("hidden", !showForm);
}

function buildPayload() {
  const payload = {
    id_maquinaria: itemEnEdicion || undefined,
    nombre: leerCampo("nombre"),
    marca: leerCampo("marca"),
  };

  if (!payload.nombre) {
    setFeedback("El nombre es obligatorio.", "error");
    return null;
  }

  return payload;
}

function leerCampo(id) {
  return document.getElementById(id).value.trim();
}

async function guardarMaquinaria(payload) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/maquinaria.php`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify(payload),
    });

    const data = await parseJsonResponse(
      response,
      "No se pudo guardar la maquinaria.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo guardar la maquinaria.");
    }

    return data;
  }

  return sendDesktopRequest("maquinaria_guardar", payload, "maquinaria_guardar_response");
}

async function eliminarMaquinaria(idMaquinaria) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/maquinaria.php`, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify({ id_maquinaria: idMaquinaria }),
    });

    const data = await parseJsonResponse(
      response,
      "No se pudo eliminar la maquinaria.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo eliminar la maquinaria.");
    }

    return data;
  }

  return sendDesktopRequest(
    "maquinaria_eliminar",
    { id_maquinaria: idMaquinaria },
    "maquinaria_eliminar_response",
  );
}

function sendDesktopRequest(type, payload, responseType) {
  if (!isDesktopWebView) {
    return Promise.reject(
      new Error("El puente de escritorio no está disponible."),
    );
  }

  const requestId = `${type}-${Date.now()}-${Math.random().toString(36).slice(2)}`;

  return new Promise((resolve, reject) => {
    const timeoutId = window.setTimeout(() => {
      window.chrome.webview.removeEventListener("message", onMessage);
      reject(new Error("La aplicación de escritorio no respondió a tiempo."));
    }, 15000);

    function onMessage(event) {
      const data =
        typeof event.data === "string" ? JSON.parse(event.data) : event.data;
      if (data.type !== responseType || data.requestId !== requestId) {
        return;
      }

      window.clearTimeout(timeoutId);
      window.chrome.webview.removeEventListener("message", onMessage);

      if (!data.success) {
        reject(new Error(data.error || "Error de escritorio."));
        return;
      }

      resolve(data);
    }

    window.chrome.webview.addEventListener("message", onMessage);
    window.chrome.webview.postMessage(
      JSON.stringify({ type, requestId, ...payload }),
    );
  });
}

async function fetchJson(url, options) {
  const response = await fetch(url, {
    credentials: "include",
    ...options,
  });
  const data = await parseJsonResponse(response, "Error de servidor.");

  if (!response.ok) {
    throw new Error(data.error || "Error de servidor.");
  }

  return data;
}

async function obtenerCsrf() {
  const data = await fetchJson(`${apiBase}/csrf.php`);
  return data.token || "";
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

async function cargarMaquinaria() {
  const solicitudId = ++ultimaSolicitudListado;
  setLoading(true);

  try {
    let data;

    if (apiBase) {
      const params = new URLSearchParams({
        page: String(paginaActual),
        limit: String(ITEMS_POR_PAGINA),
        search: terminoBusqueda,
      });
      if (filtroCertActivo) {
        params.append("estado_cert", "criticos");
      }
      data = await fetchJson(`${apiBase}/maquinaria.php?${params.toString()}`);
    } else {
      const payload = {
        page: paginaActual,
        limit: ITEMS_POR_PAGINA,
        search: terminoBusqueda,
      };
      if (filtroCertActivo) {
        payload.estado_cert = "criticos";
      }
      data = await sendDesktopRequest("maquinaria_listar", payload, "maquinaria_listar_response");
    }

    if (solicitudId !== ultimaSolicitudListado) {
      return;
    }

    maquinaria = data.maquinaria || [];
    totalItems = Number(data.total || 0);
    totalPaginas = Math.max(1, Number(data.total_pages || 1));
    paginaActual = Math.min(
      Math.max(1, Number(data.page || paginaActual)),
      totalPaginas,
    );
    renderMaquinaria();
  } finally {
    if (solicitudId === ultimaSolicitudListado) {
      setLoading(false);
    }
  }
}

function renderMaquinaria() {
  maquinariaTableBody.innerHTML = "";

  resultsCount.textContent = `${totalItems} ${totalItems === 1 ? "equipo" : "equipos"}`;
  tableWrap.classList.toggle("hidden", totalItems === 0);
  emptyState.classList.toggle("hidden", totalItems !== 0);
  pagination.classList.toggle("hidden", totalItems === 0 || totalPaginas === 1);

  if (totalItems === 0) {
    emptyStateMessage.textContent = obtenerMensajeSinResultados(
      terminoBusqueda.trim(),
    );
    paginationInfo.textContent = "Mostrando 0-0 de 0 equipos";
    paginationPage.textContent = "Página 0 de 0";
    paginationPrev.disabled = true;
    paginationNext.disabled = true;
    return;
  }

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  maquinaria.forEach((item) => {
    const row = document.createElement("tr");

    let certIcono = "";
let vencimiento = '<span style="color:#9ca3af;">No asignado</span>';

if (item.vencimiento !== null && item.vencimiento !== "" && !item.vencimiento.startsWith("0000")) {

    vencimiento = formatDate(item.vencimiento);

    const partes = item.vencimiento.split("-");
    const fechaVenc = new Date(Number(partes[0]), Number(partes[1]) - 1, Number(partes[2]));
    fechaVenc.setHours(0, 0, 0, 0);

    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const diffDays = Math.ceil(
        (fechaVenc.getTime() - hoy.getTime()) /
        (1000 * 60 * 60 * 24)
    );

    if (diffDays < 0) {

        certIcono =
            '<i class="fas fa-circle-exclamation" style="color:#b91c1c" title="Certificado vencido"></i>';

    } else if (diffDays <= 30) {

        certIcono =
            `<i class="fas fa-triangle-exclamation" style="color:#856404" title="Vence en ${diffDays} día${diffDays === 1 ? "" : "s"}"></i>`;

    }

}

    row.innerHTML = `
      <td><strong>${escapeHtml(item.nombre)}</strong>${certIcono}</td>
      <td>${escapeHtml(item.marca || "—")}</td>
      <td>${vencimiento}</td>
      <td>
        <div class="table-actions">
          <button type="button" class="action-btn" data-action="cert" data-id="${item.id_maquinaria}" title="Certificados" style="background:#e8e3df;color:#666;">
            <i class="fas fa-certificate"></i>
          </button>
          <button type="button" class="action-btn edit" data-action="edit" data-id="${item.id_maquinaria}" title="Editar maquinaria">
            <i class="fas fa-pen"></i>
          </button>
          <button type="button" class="action-btn delete" data-action="delete" data-id="${item.id_maquinaria}" title="Eliminar maquinaria">
            <i class="fas fa-trash"></i>
          </button>
        </div>
      </td>
    `;
    maquinariaTableBody.appendChild(row);
  });

  const desde =
    totalItems === 0 ? 0 : (paginaActual - 1) * ITEMS_POR_PAGINA + 1;
  const hasta = Math.min(paginaActual * ITEMS_POR_PAGINA, totalItems);
  paginationInfo.textContent = `Mostrando ${desde}-${hasta} de ${totalItems} ${totalItems === 1 ? "equipo" : "equipos"}`;
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
  await cargarMaquinaria();
}

function fillForm(item) {
    itemEnEdicion = Number(item.id_maquinaria);

    document.getElementById("id_maquinaria").value = item.id_maquinaria;
    document.getElementById("nombre").value = item.nombre || "";
    document.getElementById("marca").value = item.marca || "";

    formTitle.textContent = "Editar maquinaria";
    btnGuardar.innerHTML = '<i class="fas fa-floppy-disk"></i> Guardar cambios';

    certSection.classList.remove("hidden");

    certArchivoForm.value = "";
    certVencimientoForm.value = "";

    certListaForm.innerHTML =
        "<p style='font-size:13px;color:#888;'>Cargando certificados...</p>";

    cargarCertificadosForm(itemEnEdicion);
}

function resetForm() {
  maquinariaForm.reset();
  itemEnEdicion = null;
  document.getElementById("id_maquinaria").value = "";
  formTitle.textContent = "Registrar maquinaria";
  btnGuardar.innerHTML = '<i class="fas fa-floppy-disk"></i> Guardar maquinaria';
  certSection.classList.remove("hidden");
  certArchivoForm.value = "";
  certVencimientoForm.value = "";
  certListaForm.innerHTML = "<p style='font-size:12.5px;color:#888;margin:4px 0;'>Los certificados adjuntados se registrarán al guardar.</p>";
}

function setLoading(isLoading) {
  loadingState.classList.toggle("hidden", !isLoading);
  if (isLoading) {
    tableWrap.classList.add("hidden");
    emptyState.classList.add("hidden");
    pagination.classList.add("hidden");
  }
}

function setFeedback(message, type = "info") {
  feedbackPanel.classList.remove(
    "hidden",
    "feedback-success",
    "feedback-error",
    "feedback-info",
  );
  feedbackPanel.classList.add(`feedback-${type}`);
  feedbackTitle.textContent =
    type === "error"
      ? "No se pudo completar la acción"
      : type === "success"
        ? "Operación completada"
        : "Atención";
  feedbackMessage.textContent = message;
}

function abrirConfirmacion({ title, message, acceptLabel, onAccept }) {
  confirmTitle.textContent = title;
  confirmMessage.textContent = message;
  confirmAccept.textContent = acceptLabel;
  confirmAction = onAccept;
  confirmModal.classList.remove("hidden");
}

function cerrarConfirmacion() {
  confirmModal.classList.add("hidden");
  confirmAction = null;
  confirmAccept.textContent = "Confirmar";
}

function ocultarFeedback() {
  feedbackPanel.classList.add("hidden");
}

function obtenerMensajeSinResultados(busqueda) {
  if (!maquinaria.length) {
    return "No hay maquinaria registrada todavía.";
  }

  if (busqueda) {
    return "No se encontró maquinaria para esa búsqueda.";
  }

  return "No hay maquinaria registrada todavía.";
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function abrirCertModal(item) {
  certModal.dataset.idMaquinaria = item.id_maquinaria;
  certModalTitle.textContent = `Certificados — ${item.nombre}`;
  certArchivo.value = "";
  certVencimiento.value = "";
  certLista.innerHTML = "<p style='font-size:13px;color:#888;'>Cargando...</p>";
  certModal.classList.remove("hidden");
  cargarCertificados(item.id_maquinaria);
}

function cerrarCertModal() {
  certModal.classList.add("hidden");
  certModal.dataset.idMaquinaria = "";
  certLista.innerHTML = "";
}

function claseVencimientoCert(fechaVencimiento) {
  if (!fechaVencimiento) return "";
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const partes = fechaVencimiento.split("-");
  const vence = new Date(Number(partes[0]), Number(partes[1]) - 1, Number(partes[2]));
  vence.setHours(0, 0, 0, 0);
  const dias = Math.ceil((vence - hoy) / (1000 * 60 * 60 * 24));
  if (dias < 0) return "vencido";
  if (dias <= 15) return "critico";
  if (dias <= 30) return "advertencia";
  return "";
}

function renderCertItem(cert) {
  const clase = claseVencimientoCert(cert.fecha_vencimiento);
  let etiquetaBadge = 'Sin fecha';
  let badgeClase = 'sin-fecha';
  if (cert.fecha_vencimiento) {
    if (clase === 'vencido') {
      etiquetaBadge = 'Vencido: ' + formatDate(cert.fecha_vencimiento);
      badgeClase = 'vencido';
    } else if (clase === 'critico') {
      etiquetaBadge = 'Vence pronto: ' + formatDate(cert.fecha_vencimiento);
      badgeClase = 'critico';
    } else if (clase === 'advertencia') {
      etiquetaBadge = 'Vence: ' + formatDate(cert.fecha_vencimiento);
      badgeClase = 'advertencia';
    } else {
      etiquetaBadge = 'Vigente: ' + formatDate(cert.fecha_vencimiento);
      badgeClase = 'vigente';
    }
  }

  const nombreArchivo = cert.nombre_archivo || "Certificado";

  return `
    <div class="obrero-item cert-item ${clase}">
      <span class="obrero-name">
        <div class="cert-file-row">
          <i class="fas fa-file-pdf" style="color: #e11d48; font-size: 15px; flex-shrink: 0;"></i>
          <span class="cert-file-name" title="${escapeHtml(nombreArchivo)}">${escapeHtml(nombreArchivo)}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 6px; margin-top: 2px;">
          <span class="alerta-badge ${badgeClase}">
            ${etiquetaBadge}
          </span>
        </div>
      </span>
      <div class="obrero-actions">
        <button type="button" class="btn-download" data-descargar="${cert.id_certificado}" data-nombre="${escapeHtml(nombreArchivo)}" title="Descargar certificado" style="background: #f1f5f9; color: #334155; border: none; border-radius: 6px; padding: 6px 10px; cursor: pointer;">
          <i class="fas fa-download"></i>
        </button>
        <button type="button" class="btn-edit" data-edit-cert="${cert.id_certificado}" data-vencimiento="${cert.fecha_vencimiento || ''}" title="Editar fecha de vencimiento" style="background: #f1f5f9; color: #334155; border: none; border-radius: 6px; padding: 6px 10px; cursor: pointer;">
          <i class="fas fa-calendar-day"></i>
        </button>
        <button type="button" class="btn-delete" data-eliminar-cert="${cert.id_certificado}" title="Eliminar certificado" style="background: #fee2e2; color: #dc2626; border: none; border-radius: 6px; padding: 6px 10px; cursor: pointer;">
          <i class="fas fa-trash"></i>
        </button>
      </div>
    </div>
  `;
}

async function cargarCertificados(idMaquinaria) {
  try {
    let data;
    if (apiBase) {
      data = await fetchJson(`${apiBase}/cert_maq.php?id_maquinaria=${encodeURIComponent(idMaquinaria)}`);
    } else {
      data = await sendDesktopRequest(
        "maquinaria_certificados_listar",
        { id_maquinaria: idMaquinaria },
        "maquinaria_certificados_listar_response",
      );
    }

    const certificados = data.certificados || [];
    if (!certificados.length) {
      certLista.innerHTML = "<p style='font-size:13px;color:#888;'>No hay certificados cargados.</p>";
      certVencimiento.value = "";
      return;
    }

    certLista.innerHTML = certificados.map(renderCertItem).join("");

    const ultimo = certificados.reduce((a, b) => {
      if (!a.fecha_vencimiento) return b;
      if (!b.fecha_vencimiento) return a;
      return new Date(a.fecha_vencimiento) > new Date(b.fecha_vencimiento) ? a : b;
    }, certificados[0]);
    if (ultimo?.fecha_vencimiento) {
      certVencimiento.value = ultimo.fecha_vencimiento.substring(0, 10);
    } else {
      certVencimiento.value = "";
    }
  } catch (error) {
    console.error(error);
    certLista.innerHTML = "<p style='font-size:13px;color:#c44;'>No se pudieron cargar los certificados.</p>";
  }
}

async function cargarCertificadosForm(idMaquinaria) {
    if (!idMaquinaria) return;

    try {
        let data;
        if (apiBase) {
            data = await fetchJson(
                `${apiBase}/cert_maq.php?id_maquinaria=${encodeURIComponent(idMaquinaria)}`
            );
        } else {
            data = await sendDesktopRequest(
                "maquinaria_certificados_listar",
                { id_maquinaria: idMaquinaria },
                "maquinaria_certificados_listar_response"
            );
        }

        const certificados = data?.certificados || [];

        if (!certificados.length) {
            certListaForm.innerHTML =
                "<p style='font-size:13px;color:#888;'>No hay certificados cargados.</p>";
            certVencimientoForm.value = "";
            certVencimientoForm.dataset.ultimoCertId = "";
            certVencimientoForm.dataset.fechaOriginal = "";
            return;
        }

        certListaForm.innerHTML = certificados
            .map(renderCertItem)
            .join("");

        // ✔ Tomar el certificado con vencimiento más reciente (o el primero de la lista)
        const ultimoCert = certificados.length
            ? certificados.reduce((a, b) => {
                if (!a.fecha_vencimiento) return b;
                if (!b.fecha_vencimiento) return a;
                return new Date(a.fecha_vencimiento) > new Date(b.fecha_vencimiento) ? a : b;
            })
            : null;

        const fechaStr = ultimoCert?.fecha_vencimiento
            ? ultimoCert.fecha_vencimiento.substring(0, 10)
            : "";

        certVencimientoForm.value = fechaStr;
        certVencimientoForm.dataset.ultimoCertId = ultimoCert ? String(ultimoCert.id_certificado) : "";
        certVencimientoForm.dataset.fechaOriginal = fechaStr;

    } catch (error) {
        console.error(error);
        certListaForm.innerHTML =
            "<p style='font-size:13px;color:#c44;'>No se pudieron cargar los certificados.</p>";
    }
}

async function subirCertificado(idMaquinaria, file, fechaVencimiento) {
    validarArchivoCertificado(file);

    const fecha = (fechaVencimiento && fechaVencimiento.trim() !== "")
        ? fechaVencimiento.substring(0, 10)
        : null;

    if (apiBase) {
        const formData = new FormData();
        formData.append("id_maquinaria", String(idMaquinaria));
        formData.append("certificado", file);

        if (fecha) {
            formData.append("fecha_vencimiento", fecha);
        }

        const response = await fetch(`${apiBase}/cert_maq.php`, {
            method: "POST",
            headers: {
                "X-CSRF-Token": csrfToken
            },
            credentials: "include",
            body: formData
        });

        const data = await parseJsonResponse(response, "No se pudo subir el certificado.");

        if (!response.ok) {
            throw new Error(data.error || "No se pudo subir el certificado.");
        }

        return data;
    }

    // Desktop
    const contenidoBase64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result.split(",")[1]);
        reader.onerror = () => reject(new Error("No se pudo leer el archivo."));
        reader.readAsDataURL(file);
    });

    return sendDesktopRequest(
        "maquinaria_certificado_subir",
        {
            id_maquinaria: idMaquinaria,
            fecha_vencimiento: fecha,
            nombre_archivo: file.name,
            contenido_base64: contenidoBase64,
        },
        "maquinaria_certificado_subir_response"
    );
}

async function descargarCertificado(idCertificado, nombreArchivo) {
  try {
    let data;
    if (apiBase) {
      data = await fetchJson(`${apiBase}/cert_maq.php?descargar=${encodeURIComponent(idCertificado)}`);
    } else {
      data = await sendDesktopRequest(
        "maquinaria_certificado_descargar",
        { id_certificado: idCertificado },
        "maquinaria_certificado_descargar_response",
      );
    }

    const blob = base64ToBlob(
      data.contenido_base64,
      data.tipo_contenido || "application/octet-stream",
    );
    triggerBrowserDownload(blob, data.nombre_archivo || nombreArchivo || "certificado");
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo descargar el certificado.", "error");
  }
}

async function eliminarCertificado(idCertificado) {
  if (!confirm("¿Eliminar este certificado? Esta acción no se puede deshacer.")) return;
  try {
    let data;
    if (apiBase) {
      const response = await fetch(`${apiBase}/cert_maq.php`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        credentials: "include",
        body: JSON.stringify({ accion: "eliminar", id_certificado: idCertificado }),
      });
      data = await parseJsonResponse(response, "No se pudo eliminar el certificado.");
      if (!response.ok) {
        throw new Error(data.error || "No se pudo eliminar el certificado.");
      }
    } else {
      data = await sendDesktopRequest(
        "maquinaria_certificado_eliminar",
        { id_certificado: idCertificado },
        "maquinaria_certificado_eliminar_response",
      );
    }

    if (certModal.dataset.idMaquinaria) {
      await cargarCertificados(Number(certModal.dataset.idMaquinaria));
    }
    if (itemEnEdicion && apiBase) {
      await cargarCertificadosForm(itemEnEdicion);
    }
    setFeedback(data.message || "Certificado eliminado correctamente.", "success");
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo eliminar el certificado.", "error");
  }
}

function base64ToBlob(base64, mime) {
  const byteCharacters = atob(base64);
  const byteNumbers = new Array(byteCharacters.length);
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  const byteArray = new Uint8Array(byteNumbers);
  return new Blob([byteArray], { type: mime });
}

function triggerBrowserDownload(blob, nombreArchivo) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nombreArchivo;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function formatDate(value) {
    if (!value) return "Sin fecha";

    const clean = value.split("T")[0];
    const [year, month, day] = clean.split("-");
    if (!year || !month || !day || year === "0000") return "Sin fecha";

    return `${day}/${month}/${year}`;
}

async function cargarAlertas() {
  try {
    const data = await fetchJson(`${apiBase}/alertas_certificados.php?dias=30`);
    const alertas = data.alertas || [];
    if (!alertas.length) {
      alertasVencimiento.classList.add("hidden");
      return;
    }
    alertasVencimiento.classList.remove("hidden");
    alertasLista.innerHTML = alertas.map((a) => {
      const diasRestantes = parseInt(a.dias_restantes, 10);
      let claseBadge = "";
      if (diasRestantes < 0) claseBadge = "expirado";
      else if (diasRestantes <= 15) claseBadge = "critico";
      else claseBadge = "advertencia";
      const textoDias = diasRestantes < 0
        ? `Expirado (${Math.abs(diasRestantes)} día(s))`
        : `Vence en ${diasRestantes} día(s)`;
      return `<li>
        <span class="alerta-badge ${claseBadge}">${textoDias}</span>
        <strong>${escapeHtml(a.nombre_maquinaria)}</strong>${a.marca ? " (" + escapeHtml(a.marca) + ")" : ""}
        — ${escapeHtml(a.nombre_archivo || "Certificado")}
        <span style="margin-left:auto;font-size:11px;color:#9ca3af;">${formatDate(a.fecha_vencimiento)}</span>
      </li>`;
    }).join("");
  } catch (e) {
    console.error("Error cargando alertas:", e);
  }
}

async function editarFechaCertificado(idCertificado, fecha) {
  if (apiBase) {
    if (!csrfToken) csrfToken = await obtenerCsrf();
    const response = await fetch(`${apiBase}/cert_maq.php`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify({
        accion: "editar_fecha",
        id_certificado: idCertificado,
        fecha_vencimiento: fecha,
      }),
    });
    const data = await parseJsonResponse(response, "Error al actualizar fecha");
    if (!response.ok) throw new Error(data.error);
    return data;
  }

  return sendDesktopRequest(
    "maquinaria_certificado_editar_fecha",
    { id_certificado: idCertificado, fecha_vencimiento: fecha },
    "maquinaria_certificado_editar_fecha_response"
  );
}

function abrirEditarFechaCert(btn) {
  const idCert = btn.getAttribute("data-edit-cert");
  if (!idCert) return;

  const certItem = btn.closest(".cert-item");
  if (!certItem) return;

  const nameSpan = certItem.querySelector(".obrero-name");
  const actions = certItem.querySelector(".obrero-actions");
  if (!nameSpan || nameSpan.querySelector(".cert-edit-inline")) return;

  const textoActual = nameSpan.innerHTML;
  const vencimientoActual = btn.dataset.vencimiento ? btn.dataset.vencimiento.substring(0, 10) : "";

  if (actions) actions.style.display = "none";

  nameSpan.innerHTML = `
    <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-top:4px;">
      <input type="date" class="cert-edit-inline" value="${vencimientoActual}" style="width:140px;padding:4px 8px;border:1.5px solid #b54747;border-radius:6px;font-size:13px;">
      <button type="button" class="cert-edit-confirm" style="background:#b54747;color:#fff;border:none;border-radius:6px;padding:5px 12px;cursor:pointer;font-size:12px;font-weight:600;">Guardar</button>
      <button type="button" class="cert-edit-cancel" style="background:#64748b;color:#fff;border:none;border-radius:6px;padding:5px 10px;cursor:pointer;font-size:12px;">Cancelar</button>
    </div>
  `;

  const input = nameSpan.querySelector(".cert-edit-inline");
  const confirmBtn = nameSpan.querySelector(".cert-edit-confirm");
  const cancelBtn = nameSpan.querySelector(".cert-edit-cancel");

  function restaurar() {
    nameSpan.innerHTML = textoActual;
    if (actions) actions.style.display = "";
  }

  input.focus();

  cancelBtn.addEventListener("click", restaurar);

  confirmBtn.addEventListener("click", async () => {
    const nuevaFecha = input.value ? input.value.substring(0, 10) : "";
    if (!nuevaFecha) {
      setFeedback("Seleccioná una fecha válida.", "error");
      return;
    }
    confirmBtn.disabled = true;
    confirmBtn.textContent = "...";
    try {
      await editarFechaCertificado(idCert, nuevaFecha);
      setFeedback("Fecha de vencimiento actualizada correctamente.", "success");

      if (itemEnEdicion) {
        await cargarCertificadosForm(itemEnEdicion);
      }
      const modalMaqId = certModal?.dataset?.idMaquinaria;
      if (modalMaqId) {
        await cargarCertificados(Number(modalMaqId));
      }
      await cargarMaquinaria();
    } catch (err) {
      setFeedback(err.message || "No se pudo actualizar.", "error");
      restaurar();
    }
  });
}

document.addEventListener("click", async (e) => {

  const editCertEl = e.target.closest("[data-edit-cert]");
  if (editCertEl) {
    abrirEditarFechaCert(editCertEl);
    return;
  }

  const btn = e.target.closest("button");
  if (!btn) return;

  if (btn.dataset.descargar) {
    await descargarCertificado(
      btn.dataset.descargar,
      btn.dataset.nombre
    );
    return;
  }

  if (btn.dataset.eliminarCert) {
    await eliminarCertificado(btn.dataset.eliminarCert);
    return;
  }

});

maquinariaTableBody.addEventListener("click", async (e) => {
  const btn = e.target.closest("button");
  if (!btn) return;

  const id = btn.dataset.id;

  if (btn.dataset.action === "edit") {
    const item = maquinaria.find(m => m.id_maquinaria == id);
    if (item) {
      fillForm(item);
      togglePanels(true);
    }
  }

  if (btn.dataset.action === "delete") {
    abrirConfirmacion({
      title: "Eliminar maquinaria",
      message: "¿Seguro que querés eliminarla?",
      acceptLabel: "Eliminar",
      onAccept: async () => {
        await eliminarMaquinaria(id);
        await cargarMaquinaria();
      }
    });
  }

  if (btn.dataset.action === "cert") {
    const item = maquinaria.find(m => m.id_maquinaria == id);
    if (item) abrirCertModal(item);
  }
});

