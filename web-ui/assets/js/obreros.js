const panelObreros = document.getElementById("panelObreros");
const panelRegistro = document.getElementById("panelRegistro");
const openRegisterPanel = document.getElementById("openRegisterPanel");
const cancelRegisterPanel = document.getElementById("cancelRegisterPanel");
const obreroForm = document.getElementById("obreroForm");
const formTitle = document.getElementById("formTitle");
const btnGuardar = document.getElementById("btnGuardar");
const obreroTableBody = document.getElementById("obreroTableBody");
const searchObreros = document.getElementById("searchObreros");
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
const contratoModal = document.getElementById("contratoModal");
const contratoModalTitle = document.getElementById("contratoModalTitle");
const contratoForm = document.getElementById("contratoForm");
const contratoCancel = document.getElementById("contratoCancel");
const contratoAccept = document.getElementById("contratoAccept");
const contratoFileInput = document.getElementById("contrato_file");
const contratoFileName = document.getElementById("contratoFileName");

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
const OBREROS_POR_PAGINA = 10;

let csrfToken = "";
let obreros = [];
let totalObreros = 0;
let totalPaginas = 1;
let obreroEnEdicion = null;
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
  if (event.key === "Escape" && !contratoModal.classList.contains("hidden")) {
    cerrarContratoModal();
  }
});
contratoCancel.addEventListener("click", cerrarContratoModal);
contratoModal.addEventListener("click", (event) => {
  if (event.target === contratoModal) {
    cerrarContratoModal();
  }
});
contratoFileInput.addEventListener("change", () => {
  const file = contratoFileInput.files?.[0];
  contratoFileName.textContent = file ? file.name : "Ningún archivo seleccionado";
});
contratoAccept.addEventListener("click", async () => {
  if (!contratoAccept.dataset.idObrero) {
    cerrarContratoModal();
    return;
  }
  const file = contratoFileInput.files?.[0];
  if (!file) {
    setFeedback("Debés seleccionar un archivo.", "error");
    return;
  }
  const fechaVencimiento = document.getElementById("fecha_vencimiento").value;
  if (!fechaVencimiento) {
    setFeedback("Debés indicar una fecha de vencimiento.", "error");
    return;
  }
  contratoAccept.disabled = true;
  contratoAccept.textContent = "Guardando...";
  try {
    await subirContratoObrero(Number(contratoAccept.dataset.idObrero), file, fechaVencimiento);
    cerrarContratoModal();
    await cargarObreros();
    setFeedback("Contrato subido correctamente.", "success");
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo subir el contrato.", "error");
  } finally {
    contratoAccept.disabled = false;
    contratoAccept.textContent = "Guardar contrato";
  }
});
paginationPrev.addEventListener("click", () => cambiarPagina(-1));
paginationNext.addEventListener("click", () => cambiarPagina(1));

openRegisterPanel.addEventListener("click", () => {
  resetForm();
  togglePanels(true);
});
cancelRegisterPanel.addEventListener("click", () => {
  if (obreroEnEdicion === null) {
    togglePanels(false);
    return;
  }
  resetForm();
  togglePanels(false);
  setFeedback("Edición cancelada.", "info");
});

obreroForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const payload = buildPayload();
  if (!payload) {
    return;
  }

  btnGuardar.disabled = true;
  btnGuardar.textContent = obreroEnEdicion ? "Actualizando..." : "Guardando...";

  try {
    if (apiBase && !csrfToken) {
      csrfToken = await obtenerCsrf();
    }

    const data = await guardarObrero(payload);
    paginaActual = 1;
    await cargarObreros();
    setFeedback(data.message || "Obrero guardado correctamente.", "success");
    resetForm();
    togglePanels(false);
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo guardar el obrero.", "error");
  } finally {
    btnGuardar.disabled = false;
    btnGuardar.textContent = "Guardar";
  }
});

searchObreros.addEventListener("input", (event) => {
  terminoBusqueda = event.target.value || "";
  paginaActual = 1;
  window.clearTimeout(busquedaTimeoutId);
  busquedaTimeoutId = window.setTimeout(() => {
    cargarObreros().catch((error) => {
      console.error(error);
      setFeedback(error.message || "No se pudieron cargar los obreros.", "error");
    });
  }, 200);
});

document.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) {
    return;
  }

  const idObrero = Number.parseInt(button.dataset.id, 10);
  if (!idObrero) {
    return;
  }

  if (button.dataset.action === "edit") {
    const obrero = obreros.find((item) => item.id_obrero === idObrero);
    if (obrero) {
      abrirConfirmacion({
        title: "Confirmar edición",
        message: `¿Querés cargar "${escapeHtml(obrero.nombre)} ${escapeHtml(obrero.apellido || "")}" en el formulario para editarlo?`,
        acceptLabel: "Editar",
        onAccept: async () => {
          fillForm(obrero);
          togglePanels(true);
          setFeedback(`Editando ${obrero.nombre} ${obrero.apellido || ""}.`.trim(), "info");
        },
      });
    }
    return;
  }

  if (button.dataset.action === "delete") {
    const obrero = obreros.find((item) => item.id_obrero === idObrero);
    if (!obrero) {
      return;
    }

    abrirConfirmacion({
      title: "Confirmar eliminación",
      message: `¿Eliminar al obrero "${escapeHtml(obrero.nombre)} ${escapeHtml(obrero.apellido || "")}"? Esta acción no se puede deshacer.`,
      acceptLabel: "Eliminar",
      onAccept: async () => {
        try {
          if (apiBase && !csrfToken) {
            csrfToken = await obtenerCsrf();
          }

          const data = await eliminarObrero(idObrero);
          if (obreroEnEdicion === idObrero) {
            resetForm();
            togglePanels(false);
          }
          await cargarObreros();
          setFeedback(data.message || "Obrero eliminado correctamente.", "success");
        } catch (error) {
          console.error(error);
          setFeedback(error.message || "No se pudo eliminar el obrero.", "error");
        }
      },
    });
    return;
  }

  if (button.dataset.action === "contrato") {
    event.stopPropagation();
    const nombre = button.dataset.nombre || "";
    document.getElementById("contrato_id_obrero").value = idObrero;
    contratoModalTitle.textContent = `Subir contrato de ${nombre}`;
    contratoFileInput.value = "";
    contratoFileName.textContent = "Ningún archivo seleccionado";
    document.getElementById("fecha_vencimiento").value = "";
    contratoAccept.dataset.idObrero = String(idObrero);
    contratoModal.classList.remove("hidden");
    return;
  }
});

inicializarVista().catch((error) => {
  console.error(error);
  setFeedback(error.message || "No se pudieron cargar los obreros.", "error");
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
    await cargarObreros();
  } finally {
    setLoading(false);
  }
}

function togglePanels(showRegister) {
  panelObreros.classList.toggle("hidden", showRegister);
  panelRegistro.classList.toggle("hidden", !showRegister);
}

function buildPayload() {
  const payload = {
    id_obrero: obreroEnEdicion || undefined,
    nombre: leerCampo("nombre"),
    apellido: leerCampo("apellido"),
    documento: leerCampo("documento"),
    telefono: leerCampo("telefono"),
    fecha_contratacion: leerCampo("fecha_contratacion") || null,
  };

  if (!payload.nombre || !payload.documento) {
    setFeedback("Nombre y documento son obligatorios.", "error");
    return null;
  }

  return payload;
}

function leerCampo(id) {
  return document.getElementById(id).value.trim();
}

async function guardarObrero(payload) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/obreros.php`, {
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
      "No se pudo guardar el obrero.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo guardar el obrero.");
    }

    return data;
  }

  return sendDesktopRequest("obreros_guardar", payload, "obreros_guardar_response");
}

async function eliminarObrero(idObrero) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/obreros.php`, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify({ id_obrero: idObrero }),
    });

    const data = await parseJsonResponse(
      response,
      "No se pudo eliminar el obrero.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo eliminar el obrero.");
    }

    return data;
  }

  return sendDesktopRequest(
    "obreros_eliminar",
    { id_obrero: idObrero },
    "obreros_eliminar_response",
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

async function cargarObreros() {
  const solicitudId = ++ultimaSolicitudListado;
  setLoading(true);

  try {
    let data;

    if (apiBase) {
      const params = new URLSearchParams({
        page: String(paginaActual),
        limit: String(OBREROS_POR_PAGINA),
        search: terminoBusqueda,
      });
      data = await fetchJson(`${apiBase}/obreros.php?${params.toString()}`);
    } else {
      data = await sendDesktopRequest(
        "obreros_listar",
        {
          page: paginaActual,
          limit: OBREROS_POR_PAGINA,
          search: terminoBusqueda,
        },
        "obreros_listar_response",
      );
    }

    if (solicitudId !== ultimaSolicitudListado) {
      return;
    }

    obreros = data.obreros || [];
    totalObreros = Number(data.total || 0);
    totalPaginas = Math.max(1, Number(data.total_pages || 1));
    paginaActual = Math.min(
      Math.max(1, Number(data.page || paginaActual)),
      totalPaginas,
    );
    renderObreros();
  } finally {
    if (solicitudId === ultimaSolicitudListado) {
      setLoading(false);
    }
  }
}

function renderObreros() {
  obreroTableBody.innerHTML = "";

  resultsCount.textContent = `${totalObreros} ${totalObreros === 1 ? "obrero" : "obreros"}`;
  tableWrap.classList.toggle("hidden", totalObreros === 0);
  emptyState.classList.toggle("hidden", totalObreros !== 0);
  pagination.classList.toggle("hidden", totalObreros === 0 || totalPaginas === 1);

  if (totalObreros === 0) {
    emptyStateMessage.textContent = obtenerMensajeSinResultados(
      terminoBusqueda.trim(),
    );
    paginationInfo.textContent = "Mostrando 0-0 de 0 obreros";
    paginationPage.textContent = "Página 0 de 0";
    paginationPrev.disabled = true;
    paginationNext.disabled = true;
    return;
  }

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  obreros.forEach((obrero) => {
    const row = document.createElement("tr");
    let claseAlerta = "";
    if (obrero.vencimiento) {
      const fechaVenc = new Date(obrero.vencimiento);
      const diffDays = Math.ceil((fechaVenc - hoy) / (1000 * 60 * 60 * 24));
      if (diffDays <= 30 && diffDays > 0) {
        claseAlerta = "table-warning";
      } else if (diffDays <= 0) {
        claseAlerta = "table-danger";
      }
    }
    if (claseAlerta) {
      row.classList.add(claseAlerta);
    }

    row.innerHTML = `
      <td><strong>${escapeHtml(obrero.nombre)}</strong> ${escapeHtml(obrero.apellido || "")}</td>
      <td>${escapeHtml(obrero.documento)}</td>
      <td>${escapeHtml(obrero.telefono || "—")}</td>
      <td>${formatDate(obrero.fecha_contratacion)}</td>
      <td>
        <div class="table-actions">
          <button type="button" class="action-btn edit" data-action="edit" data-id="${obrero.id_obrero}" title="Editar obrero">
            <i class="fas fa-pen"></i>
          </button>
          <button type="button" class="action-btn delete" data-action="delete" data-id="${obrero.id_obrero}" title="Eliminar obrero">
            <i class="fas fa-trash"></i>
          </button>
          <button type="button" class="action-btn" style="background:#d88f2d;color:#fff;" data-action="contrato" data-id="${obrero.id_obrero}" data-nombre="${escapeHtml(obrero.nombre + " " + (obrero.apellido || "")).trim()}" title="Subir contrato">
            <i class="fas fa-file-pdf"></i>
          </button>
        </div>
      </td>
    `;
    obreroTableBody.appendChild(row);
  });

  const desde =
    totalObreros === 0 ? 0 : (paginaActual - 1) * OBREROS_POR_PAGINA + 1;
  const hasta = Math.min(paginaActual * OBREROS_POR_PAGINA, totalObreros);
  paginationInfo.textContent = `Mostrando ${desde}-${hasta} de ${totalObreros} ${totalObreros === 1 ? "obrero" : "obreros"}`;
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
  await cargarObreros();
}

function fillForm(obrero) {
  obreroEnEdicion = obrero.id_obrero;
  document.getElementById("id_obrero").value = obrero.id_obrero;
  document.getElementById("nombre").value = obrero.nombre || "";
  document.getElementById("apellido").value = obrero.apellido || "";
  document.getElementById("documento").value = obrero.documento || "";
  document.getElementById("telefono").value = obrero.telefono || "";
  document.getElementById("fecha_contratacion").value = obrero.fecha_contratacion || "";
  formTitle.textContent = "Editar obrero";
  btnGuardar.textContent = "Guardar";
}

function resetForm() {
  obreroForm.reset();
  obreroEnEdicion = null;
  document.getElementById("id_obrero").value = "";
  formTitle.textContent = "Registrar obrero";
  btnGuardar.textContent = "Guardar";
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

function formatDate(value) {
  if (!value) {
    return "Sin fecha";
  }

  const [year, month, day] = value.split("-");
  if (!year || !month || !day) {
    return value;
  }

  return `${day}/${month}/${year}`;
}

function obtenerMensajeSinResultados(busqueda) {
  if (!obreros.length) {
    return "No hay obreros registrados todavía.";
  }

  if (busqueda) {
    return "No se encontraron obreros para esa búsqueda.";
  }

  return "No hay obreros registrados todavía.";
}

function cerrarContratoModal() {
  contratoModal.classList.add("hidden");
  contratoAccept.dataset.idObrero = "";
}

async function subirContratoObrero(idObrero, file, fechaVencimiento) {
  if (apiBase) {
    const formData = new FormData();
    formData.append("accion", "subir_contrato");
    formData.append("id_obrero", String(idObrero));
    formData.append("fecha_vencimiento", fechaVencimiento);
    formData.append("contrato", file);

    const response = await fetch(`${apiBase}/obreros.php`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: formData,
    });

    const data = await parseJsonResponse(response, "No se pudo subir el contrato.");
    if (!response.ok) {
      throw new Error(data.error || "No se pudo subir el contrato.");
    }
    return data;
  }

  return sendDesktopRequest(
    "obreros_subir_contrato",
    { id_obrero: idObrero, fecha_vencimiento: fechaVencimiento, nombre_archivo: file.name },
    "obreros_subir_contrato_response",
  );
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
