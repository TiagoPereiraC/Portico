const obraForm = document.getElementById("obraForm");
const formTitle = document.getElementById("formTitle");
const btnGuardar = document.getElementById("btnGuardar");
const btnBack = document.querySelector(".btn-back");
const contratoInput = document.getElementById("contrato_archivo");
const contratoEstado = document.getElementById("contratoEstado");
const contratoNombre = document.getElementById("contratoNombre");
const obrasTableBody = document.getElementById("obrasTableBody");
const resultsCount = document.getElementById("resultsCount");
const tableWrap = document.getElementById("tableWrap");
const loadingState = document.getElementById("loadingState");
const emptyState = document.getElementById("emptyState");
const pagination = document.getElementById("pagination");
const paginationInfo = document.getElementById("paginationInfo");
const paginationPage = document.getElementById("paginationPage");
const paginationPrev = document.getElementById("paginationPrev");
const paginationNext = document.getElementById("paginationNext");
const searchObras = document.getElementById("searchObras");
const filterEstadoObras = document.getElementById("filterEstadoObras");
const emptyStateMessage = document.getElementById("emptyStateMessage");
const feedbackPanel = document.getElementById("feedbackPanel");
const feedbackTitle = document.getElementById("feedbackTitle");
const feedbackMessage = document.getElementById("feedbackMessage");
const feedbackClose = document.getElementById("feedbackClose");
const confirmModal = document.getElementById("confirmModal");
const confirmTitle = document.getElementById("confirmTitle");
const confirmMessage = document.getElementById("confirmMessage");
const confirmCancel = document.getElementById("confirmCancel");
const confirmAccept = document.getElementById("confirmAccept");
const obraDetailModal = document.getElementById("obraDetailModal");
const detailClose = document.getElementById("detailClose");
const detailModalTitle = document.getElementById("detailModalTitle");
const detailContrata = document.getElementById("detailContrata");
const detailStatus = document.getElementById("detailStatus");
const detailInfo = document.getElementById("detailInfo");
const detailMaterialesWrap = document.getElementById("detailMaterialesWrap");
const detailMaterialesBody = document.getElementById("detailMaterialesBody");
const detailMaterialesEmpty = document.getElementById("detailMaterialesEmpty");
const detailHerramientasWrap = document.getElementById("detailHerramientasWrap");
const detailHerramientasBody = document.getElementById("detailHerramientasBody");
const detailHerramientasEmpty = document.getElementById("detailHerramientasEmpty");
const detailObrerosWrap = document.getElementById("detailObrerosWrap");
const detailObrerosBody = document.getElementById("detailObrerosBody");
const detailObrerosEmpty = document.getElementById("detailObrerosEmpty");
const detailMaquinariaWrap = document.getElementById("detailMaquinariaWrap");
const detailMaquinariaBody = document.getElementById("detailMaquinariaBody");
const detailMaquinariaEmpty = document.getElementById("detailMaquinariaEmpty");
const detailBtnEdit = document.getElementById("detailBtnEdit");
const detailBtnDownload = document.getElementById("detailBtnDownload");
const detailBtnDelete = document.getElementById("detailBtnDelete");
const detailBtnToggleStatus = document.getElementById("detailBtnToggleStatus");
const detailToggleStatusText = document.getElementById("detailToggleStatusText");
const detailBtnMap = document.getElementById("detailBtnMap");
const detailMapSection = document.getElementById("detailMapSection");
const detailMapIframe = document.getElementById("detailMapIframe");
const isDesktopWebView = Boolean(window.chrome?.webview);
const detailMaterialesTotal = document.getElementById("detailMaterialesTotal");

const detailTareasTotal = document.getElementById("detailTareasTotal");
const detailTareasCompletadas = document.getElementById("detailTareasCompletadas");
const detailTareasPendientes = document.getElementById("detailTareasPendientes");
const detailTareasGanado = document.getElementById("detailTareasGanado");

const detailTareasCompletadasWrap =
    document.getElementById("detailTareasCompletadasWrap");

const detailTareasCompletadasBody =
    document.getElementById("detailTareasCompletadasBody");

const detailTareasCompletadasEmpty =
    document.getElementById("detailTareasCompletadasEmpty");

const detailTareasPendientesWrap =
    document.getElementById("detailTareasPendientesWrap");

const detailTareasPendientesBody =
    document.getElementById("detailTareasPendientesBody");

const detailTareasPendientesEmpty =
    document.getElementById("detailTareasPendientesEmpty");

// =========================================================
// ACTIVIDADES DEL CONTRATO
// =========================================================

const btnAgregarTarea = document.getElementById("btnAgregarTarea");
const contratoTareasBody = document.getElementById("contratoTareasBody");
const tareasEmpty = document.getElementById("tareasEmpty");
const totalContrato = document.getElementById("totalContrato");

let tareasContrato = [];

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
const MAX_CONTRATO_SIZE = 10 * 1024 * 1024;
const OBRAS_POR_PAGINA = 10;

let csrfToken = "";
let obras = [];
let totalObras = 0;
let totalPaginas = 1;
let obraEnEdicion = null;
let confirmAction = null;
let paginaActual = 1;
let terminoBusqueda = "";
let filtroEstado = "all";
let busquedaTimeoutId = null;
let ultimaSolicitudListado = 0;

feedbackClose.addEventListener("click", ocultarFeedback);
contratoInput.addEventListener("change", actualizarEstadoContratoSeleccionado);
btnBack.addEventListener("click", (event) => {
  if (obraEnEdicion === null) {
    return;
  }

  event.preventDefault();
  resetForm();
  setFeedback("Edición cancelada.", "info");
});

if (btnAgregarTarea) {
  btnAgregarTarea.addEventListener("click", agregarTarea);
}
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
searchObras.addEventListener("input", (event) => {
  terminoBusqueda = event.target.value || "";
  paginaActual = 1;
  window.clearTimeout(busquedaTimeoutId);
  busquedaTimeoutId = window.setTimeout(() => {
    cargarObras().catch((error) => {
      console.error(error);
      setFeedback(error.message || "No se pudieron cargar las obras.", "error");
    });
  }, 200);
});
filterEstadoObras.addEventListener("change", (event) => {
  filtroEstado = event.target.value || "all";
  paginaActual = 1;
  cargarObras().catch((error) => {
    console.error(error);
    setFeedback(error.message || "No se pudieron cargar las obras.", "error");
  });
});

detailClose.addEventListener("click", cerrarDetalle);
obraDetailModal.addEventListener("click", (event) => {
  if (event.target === obraDetailModal) {
    cerrarDetalle();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !obraDetailModal.classList.contains("hidden")) {
    cerrarDetalle();
  }
});

obraForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const payload = await buildPayload();
  if (!payload) {
    return;
  }

  btnGuardar.disabled = true;
  btnGuardar.textContent = obraEnEdicion ? "Actualizando..." : "Guardando...";

  try {
    if (apiBase && !csrfToken) {
      csrfToken = await obtenerCsrf();
    }

    const data = await guardarObra(payload);
    paginaActual = 1;
    await cargarObras();
    setFeedback(data.message || "Obra guardada correctamente.", "success");
    resetForm();
  } catch (error) {
    console.error(error);
    setFeedback(error.message || "No se pudo guardar la obra.", "error");
  } finally {
    btnGuardar.disabled = false;
    btnGuardar.textContent = "Guardar";
  }
});

// =========================================================
// COMPLETAR ACTIVIDAD DESDE EL DETALLE DE LA OBRA
// =========================================================

document.addEventListener("click", (event) => {
  const button = event.target.closest(
    "button[data-task-action='complete']"
  );

  if (!button) {
    return;
  }

  const idTarea = Number.parseInt(
    button.dataset.tareaId,
    10
  );

  const idObra = Number.parseInt(
    button.dataset.obraId,
    10
  );

  if (!idTarea || !idObra) {
    setFeedback(
      "No se pudo identificar la actividad.",
      "error"
    );
    return;
  }

  abrirConfirmacion({
    title: "Completar actividad",

    message:
      "¿Estás seguro de que querés marcar esta actividad como completada?",

    acceptLabel: "Completar",

    onAccept: async () => {
      try {
        if (apiBase && !csrfToken) {
          csrfToken = await obtenerCsrf();
        }

        const data = await completarTarea(idTarea);

        setFeedback(
          data.message ||
            "Actividad marcada como completada correctamente.",
          "success"
        );

        // Volver a cargar el detalle de la obra
        await cargarDetalleObra(idObra);

        // Actualizar también la lista de obras
        await cargarObras();

      } catch (error) {
        console.error(error);

        setFeedback(
          error.message ||
            "No se pudo completar la actividad.",
          "error"
        );
      }
    },
  });
});

document.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) {
    return;
  }

  const idObra = Number.parseInt(button.dataset.id, 10);
  if (!idObra) {
    return;
  }

  if (button.dataset.action === "view") {
    abrirDetalle(idObra);
    return;
  }

  if (button.dataset.action === "edit") {
  const obra = obras.find(
    (item) => Number(item.id_obra) === idObra
  );

  if (!obra) {
    return;
  }

  abrirConfirmacion({
    title: "Confirmar edición",
    message: `¿Querés cargar "${obra.nombre}" en el formulario para editarla?`,
    acceptLabel: "Editar",

    onAccept: async () => {
      try {
        const data = await obtenerDetalleObra(idObra);

        const obraCompleta = {
          ...data.obra,
          tareas: data.tareas || [],
        };

        fillForm(obraCompleta);

        setFeedback(
          `Editando ${obra.nombre}.`,
          "info"
        );
      } catch (error) {
        console.error(error);

        setFeedback(
          error.message ||
            "No se pudieron cargar las actividades de la obra.",
          "error"
        );
      }
    },
  });

  return;
}

  if (button.dataset.action === "download") {
    try {
      await descargarContrato(idObra);
    } catch (error) {
      console.error(error);
      setFeedback(
        error.message || "No se pudo descargar el contrato.",
        "error",
      );
    }
    return;
  }

  if (button.dataset.action === "delete") {
    const obra = obras.find((item) => item.id_obra === idObra);
    if (!obra) {
      return;
    }

    abrirConfirmacion({
      title: "Confirmar eliminación",
      message: `¿Eliminar la obra "${obra.nombre}"? Esta acción no se puede deshacer.`,
      acceptLabel: "Eliminar",
      onAccept: async () => {
        try {
          if (apiBase && !csrfToken) {
            csrfToken = await obtenerCsrf();
          }

          const data = await eliminarObra(idObra);
          if (obraEnEdicion === idObra) {
            resetForm();
          }
          await cargarObras();
          setFeedback(
            data.message || "Obra eliminada correctamente.",
            "success",
          );
        } catch (error) {
          console.error(error);
          setFeedback(error.message || "No se pudo eliminar la obra.", "error");
        }
      },
    });
  }
});

inicializarVista().catch((error) => {
  console.error(error);
  setFeedback(error.message || "No se pudieron cargar las obras.", "error");
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

    await cargarObras();
  } finally {
    setLoading(false);
  }
}

async function buildPayload() {
  const payload = {
    id_obra: leerCampo("id_obra") || undefined,
    numero_contrata: leerCampo("numero_contrata"),
    nombre: leerCampo("nombre"),
    direccion: leerCampo("direccion"),
    descripcion: leerCampo("descripcion"),
    fecha_inicio: leerCampo("fecha_inicio"),
    fecha_fin: obraEnEdicion
      ? obras.find((item) => item.id_obra === obraEnEdicion)?.fecha_fin || ""
      : "",
    nombre_cliente: leerCampo("nombre_cliente"),
    telefono_cliente: leerCampo("telefono_cliente"),
    activo: document.getElementById("activo").checked ? 1 : 0,
    tareas: tareasContrato.map((tarea) => ({
      id_tarea: tarea.id_tarea,
      id_tarea_origen: tarea.id_tarea_origen || null,
      descripcion: tarea.descripcion.trim(),
      importe: Number(tarea.importe || 0),
      estado: tarea.estado || "Pendiente",
      fecha_completada: tarea.fecha_completada || null,
    })),
  };

  if (!payload.numero_contrata || !payload.nombre || !payload.nombre_cliente) {
    setFeedback(
      "Número de contrata, nombre de la obra y cliente son obligatorios.",
      "error",
    );
    return null;
  }

  if (
    payload.fecha_inicio &&
    payload.fecha_fin &&
    payload.fecha_fin < payload.fecha_inicio
  ) {
    setFeedback("La fecha de fin no puede ser menor a la de inicio.", "error");
    return null;
  }

  const contrato = await leerContratoSeleccionado();

  for (const tarea of tareasContrato) {
  if (!tarea.descripcion.trim()) {
    setFeedback(
      "Todas las actividades deben tener una descripción.",
      "error"
    );
    return null;
  }

  if (Number(tarea.importe) < 0) {
    setFeedback(
      "El importe de una actividad no puede ser negativo.",
      "error"
    );
    return null;
  }
}

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
      "No se pudo guardar la obra.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo guardar la obra.");
    }

    return data;
  }

  return sendDesktopRequest("obras_guardar", payload, "obras_guardar_response");
}

async function eliminarObra(idObra) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php`, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify({ id_obra: idObra }),
    });

    const data = await parseJsonResponse(
      response,
      "No se pudo eliminar la obra.",
    );
    if (!response.ok) {
      throw new Error(data.error || "No se pudo eliminar la obra.");
    }

    return data;
  }

  return sendDesktopRequest(
    "obras_eliminar",
    { id_obra: idObra },
    "obras_eliminar_response",
  );
}

async function descargarContrato(idObra) {
  if (apiBase) {
    const response = await fetch(
      `${apiBase}/Obras.php?id_obra=${encodeURIComponent(idObra)}&descargar_contrato=1`,
      {
        credentials: "include",
      },
    );

    if (!response.ok) {
      const text = await response.text();
      try {
        const data = JSON.parse(text);
        throw new Error(data.error || "No se pudo descargar el contrato.");
      } catch {
        throw new Error("No se pudo descargar el contrato.");
      }
    }

    const blob = await response.blob();
    const nombreArchivo =
      getFileNameFromDisposition(response.headers.get("Content-Disposition")) ||
      obras.find((item) => item.id_obra === idObra)?.contrato_nombre_archivo ||
      `contrato-${idObra}`;
    triggerBrowserDownload(blob, nombreArchivo);
    return;
  }

  const data = await sendDesktopRequest(
    "obras_descargar_contrato",
    { id_obra: idObra },
    "obras_descargar_contrato_response",
  );
  if (!data.contenido_base64 || !data.nombre_archivo) {
    throw new Error("No se pudo descargar el contrato.");
  }

  const blob = base64ToBlob(
    data.contenido_base64,
    data.tipo_contenido || "application/octet-stream",
  );
  triggerBrowserDownload(blob, data.nombre_archivo);
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

async function cargarObras() {
  const solicitudId = ++ultimaSolicitudListado;
  setLoading(true);

  try {
    let data;

    if (apiBase) {
      const params = new URLSearchParams({
        page: String(paginaActual),
        limit: String(OBRAS_POR_PAGINA),
        search: terminoBusqueda,
        status: filtroEstado,
      });
      data = await fetchJson(`${apiBase}/Obras.php?${params.toString()}`);
    } else {
      data = await sendDesktopRequest(
        "obras_listar",
        {
          page: paginaActual,
          limit: OBRAS_POR_PAGINA,
          search: terminoBusqueda,
          status: filtroEstado,
        },
        "obras_listar_response",
      );
    }

    if (solicitudId !== ultimaSolicitudListado) {
      return;
    }

    obras = data.obras || [];
    totalObras = Number(data.total || 0);
    totalPaginas = Math.max(1, Number(data.total_pages || 1));
    paginaActual = Math.min(
      Math.max(1, Number(data.page || paginaActual)),
      totalPaginas,
    );
    renderObras();
  } finally {
    if (solicitudId === ultimaSolicitudListado) {
      setLoading(false);
    }
  }
}

function renderObras() {
  obrasTableBody.innerHTML = "";

  resultsCount.textContent = `${totalObras} ${totalObras === 1 ? "obra" : "obras"}`;
  tableWrap.classList.toggle("hidden", totalObras === 0);
  emptyState.classList.toggle("hidden", totalObras !== 0);
  pagination.classList.toggle("hidden", totalObras === 0 || totalPaginas === 1);

  if (totalObras === 0) {
    emptyStateMessage.textContent = obtenerMensajeSinResultados(
      terminoBusqueda.trim(),
      filtroEstado,
    );
    paginationInfo.textContent = "Mostrando 0-0 de 0 obras";
    paginationPage.textContent = "Página 0 de 0";
    paginationPrev.disabled = true;
    paginationNext.disabled = true;
    return;
  }

  obras.forEach((obra) => {
    const row = document.createElement("tr");
    row.dataset.id = obra.id_obra;
    row.innerHTML = `
      <td>${escapeHtml(obra.numero_contrata)}</td>
      <td>
        <strong>${escapeHtml(obra.nombre)}</strong>
        <span class="table-subline">${escapeHtml(obra.direccion || "Sin dirección cargada")}</span>
        <span class="table-subline">${escapeHtml(obra.contrato_nombre_archivo ? `Contrato: ${obra.contrato_nombre_archivo}` : "Sin contrato cargado")}</span>
      </td>
      <td>${escapeHtml(obra.nombre_cliente)}</td>
      <td>${formatDate(obra.fecha_inicio)}</td>
      <td>${formatDate(obra.fecha_fin)}</td>
      <td>
        <div class="table-actions">
          <button type="button" class="action-btn edit" data-action="view" data-id="${obra.id_obra}" title="Ver detalle">
            <i class="fas fa-eye"></i>
          </button>
        </div>
      </td>
    `;
    row.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-action]");
      if (button) {
        return;
      }
      abrirDetalle(obra.id_obra);
    });
    obrasTableBody.appendChild(row);
  });

  const desde =
    totalObras === 0 ? 0 : (paginaActual - 1) * OBRAS_POR_PAGINA + 1;
  const hasta = Math.min(paginaActual * OBRAS_POR_PAGINA, totalObras);
  paginationInfo.textContent = `Mostrando ${desde}-${hasta} de ${totalObras} ${totalObras === 1 ? "obra" : "obras"}`;
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
  await cargarObras();
}

function setLoading(isLoading) {
  loadingState.classList.toggle("hidden", !isLoading);
  if (isLoading) {
    tableWrap.classList.add("hidden");
    emptyState.classList.add("hidden");
    pagination.classList.add("hidden");
  }
}

function fillForm(obra) {
  obraEnEdicion = Number(obra.id_obra);

  document.getElementById("id_obra").value = obra.id_obra;
  document.getElementById("numero_contrata").value =
    obra.numero_contrata || "";

  document.getElementById("nombre").value =
    obra.nombre || "";

  document.getElementById("direccion").value =
    obra.direccion || "";

  document.getElementById("descripcion").value =
    obra.descripcion || "";

  document.getElementById("fecha_inicio").value =
    obra.fecha_inicio || "";

  document.getElementById("nombre_cliente").value =
    obra.nombre_cliente || "";

  document.getElementById("telefono_cliente").value =
    obra.telefono_cliente || "";

  document.getElementById("activo").checked =
    obra.activo === 1 || obra.activo === "1";

  // No reemplazar el contrato existente
  contratoInput.value = "";

  actualizarEstadoContratoActual(
    obra.contrato_nombre_archivo || ""
  );

  // =========================================================
  // CARGAR ACTIVIDADES DEL CONTRATO
  // =========================================================

  tareasContrato = Array.isArray(obra.tareas)
    ? obra.tareas.map((tarea) => ({
        id_tarea: Number(tarea.id_tarea),
        id_tarea_origen: tarea.id_tarea_origen
          ? Number(tarea.id_tarea_origen)
          : null,
        descripcion: tarea.descripcion || "",
        importe: Number(tarea.importe || 0),
        estado: tarea.estado || "Pendiente",
        fecha_completada: tarea.fecha_completada || null,
      }))
    : [];

  renderTareasContrato();

  formTitle.textContent =
    "Editando: " + obra.nombre;

  btnGuardar.textContent =
    "Guardar cambios";

  btnBack.textContent =
    "Cancelar edición";

  document
    .querySelector(".editor-panel")
    .classList.add("editing");

  document
    .querySelector(".layout-grid")
    .classList.add("editing-list");
}

function resetForm() {
  obraForm.reset();
  obraEnEdicion = null;
  tareasContrato = [];
  renderTareasContrato();
  document.getElementById("id_obra").value = "";
  contratoInput.value = "";
  actualizarEstadoContratoActual("");
  formTitle.textContent = "Nueva obra";
  btnGuardar.textContent = "Guardar";
  btnBack.textContent = "Volver";
  document.querySelector(".editor-panel").classList.remove("editing");
  document.querySelector(".layout-grid").classList.remove("editing-list");
}

async function leerContratoSeleccionado() {
  const file = contratoInput.files?.[0];
  if (!file) {
    return null;
  }

  if (file.size > MAX_CONTRATO_SIZE) {
    setFeedback("El contrato no puede superar los 10 MB.", "error");
    return false;
  }

  if (file.name.length > 255) {
    setFeedback("El nombre del archivo es demasiado largo.", "error");
    return false;
  }

  try {
    const dataUrl = await readFileAsDataUrl(file);
    const commaIndex = dataUrl.indexOf(",");
    if (commaIndex === -1) {
      throw new Error("Formato de archivo inválido.");
    }

    return {
      nombre_archivo: file.name,
      tipo_contenido: file.type || "application/octet-stream",
      contenido_base64: dataUrl.slice(commaIndex + 1),
    };
  } catch (error) {
    setFeedback(
      error.message || "No se pudo leer el contrato seleccionado.",
      "error",
    );
    return false;
  }
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () =>
      reject(new Error("No se pudo leer el contrato seleccionado."));
    reader.readAsDataURL(file);
  });
}

function actualizarEstadoContratoSeleccionado() {
  const file = contratoInput.files?.[0];
  if (file) {
    contratoNombre.textContent = file.name;
    contratoEstado.textContent = "Archivo listo para subir.";
    return;
  }

  const obraActual = obras.find((item) => item.id_obra === obraEnEdicion);
  actualizarEstadoContratoActual(obraActual?.contrato_nombre_archivo || "");
}

function actualizarEstadoContratoActual(nombreArchivo) {
  if (nombreArchivo) {
    contratoNombre.textContent = nombreArchivo;
    contratoEstado.textContent = "Contrato cargado actualmente.";
  } else {
    contratoNombre.textContent = "Ningún archivo seleccionado";
    contratoEstado.textContent = "Sin contrato cargado.";
  }
}

function triggerBrowserDownload(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
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
    return "";
  }

  const utfMatch = disposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utfMatch?.[1]) {
    return decodeURIComponent(utfMatch[1]);
  }

  const match = disposition.match(/filename="?([^";]+)"?/i);
  return match?.[1] || "";
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

let obraDetalleActual = null;

function abrirDetalle(idObra) {
  obraDetalleActual = idObra;
  cargarDetalleObra(idObra).catch((error) => {
    console.error(error);
    setFeedback(error.message || "No se pudo cargar el detalle de la obra.", "error");
  });
}

function cerrarDetalle() {
  obraDetailModal.classList.add("hidden");
  obraDetailModal.style.display = "none";
  obraDetalleActual = null;
  if (detailBtnEdit) detailBtnEdit.onclick = null;
  if (detailBtnDownload) detailBtnDownload.onclick = null;
  if (detailBtnDelete) detailBtnDelete.onclick = null;
  if (detailBtnToggleStatus) detailBtnToggleStatus.onclick = null;
  if (detailBtnMap) detailBtnMap.onclick = null;
  if (detailMapSection) detailMapSection.classList.add("hidden");
  if (detailMapIframe) detailMapIframe.src = "";
}

async function cargarDetalleObra(idObra) {
  let data;

  if (apiBase) {
    data = await fetchJson(`${apiBase}/Obras.php?id_obra=${encodeURIComponent(idObra)}&detalle=1`);
  } else {
    data = await sendDesktopRequest(
      "obras_detalle",
      { id_obra: idObra },
      "obras_detalle_response",
    );
  }

  renderDetalle(data);
  obraDetailModal.style.display = "";
  obraDetailModal.classList.remove("hidden");
}

function renderDetalle(data) {
  const obra = data.obra || {};
  const materiales = data.materiales || [];
  const herramientas = data.herramientas || [];
  const obreros = data.obreros || [];
  const maquinaria = data.maquinaria || [];
  const recursos = data.recursos || [];
  const tareas = data.tareas || [];
  detailModalTitle.textContent = obra.nombre || "Detalle de obra";
  detailContrata.textContent = obra.numero_contrata || "";

  const esActiva = obra.activo === 1 || obra.activo === "1";

  detailStatus.textContent = esActiva ? "Activa" : "Inactiva";
  detailStatus.className =
    "detail-status" + (esActiva ? "" : " inactive");

  // =========================================================
  // INFORMACIÓN GENERAL
  // =========================================================

  detailInfo.innerHTML = `
    <div class="detail-item">
      <span class="detail-label">Cliente</span>
      <span class="detail-value">
        ${escapeHtml(obra.nombre_cliente || "—")}
      </span>
    </div>

    <div class="detail-item">
      <span class="detail-label">Teléfono</span>
      <span class="detail-value">
        ${escapeHtml(obra.telefono_cliente || "—")}
      </span>
    </div>

    <div class="detail-item">
      <span class="detail-label">Dirección</span>
      <span class="detail-value">
        ${escapeHtml(obra.direccion || "—")}
      </span>
    </div>

    <div class="detail-item">
      <span class="detail-label">Inicio</span>
      <span class="detail-value">
        ${formatDate(obra.fecha_inicio)}
      </span>
    </div>

    <div class="detail-item">
      <span class="detail-label">Fin</span>
      <span class="detail-value">
        ${formatDate(obra.fecha_fin)}
      </span>
    </div>

    <div class="detail-item full">
      <span class="detail-label">Descripción</span>
      <span class="detail-value">
        ${escapeHtml(obra.descripcion || "—")}
      </span>
    </div>

    <div class="detail-item full">
      <span class="detail-label">Contrato</span>
      <span class="detail-value">
        ${escapeHtml(
          obra.contrato_nombre_archivo || "Sin contrato cargado"
        )}
      </span>
    </div>
  `;

  // =========================================================
  // MATERIALES
  // =========================================================

  if (materiales.length) {
    detailMaterialesWrap.classList.remove("hidden");
    detailMaterialesEmpty.classList.add("hidden");

    let granTotalMateriales = 0;

    detailMaterialesBody.innerHTML = materiales
      .map((m) => {
        const cantidad = Number(m.cantidad_total || 0);
        const costoTotal = Number(m.costo_total || 0);

        const precioUnitario =
          cantidad > 0 ? costoTotal / cantidad : 0;

        granTotalMateriales += costoTotal;

        return `
          <tr>
            <td>
              ${escapeHtml(m.nombre || "—")}
            </td>

            <td>
              ${cantidad.toLocaleString("es-UY")}
            </td>

            <td>
              $ ${precioUnitario.toLocaleString("es-UY", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}
            </td>

            <td>
              $ ${costoTotal.toLocaleString("es-UY", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}
            </td>
          </tr>
        `;
      })
      .join("");

    // Total general de materiales
    if (typeof detailMaterialesTotal !== "undefined" && detailMaterialesTotal) {
      detailMaterialesTotal.textContent =
        `$ ${granTotalMateriales.toLocaleString("es-UY", {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        })}`;
    }
  } else {
    detailMaterialesWrap.classList.add("hidden");
    detailMaterialesEmpty.classList.remove("hidden");
    detailMaterialesBody.innerHTML = "";

    if (
      typeof detailMaterialesTotal !== "undefined" &&
      detailMaterialesTotal
    ) {
      detailMaterialesTotal.textContent = "$ 0,00";
    }
  }

  // =========================================================
  // HERRAMIENTAS
  // =========================================================

  if (herramientas.length) {
    detailHerramientasWrap.classList.remove("hidden");
    detailHerramientasEmpty.classList.add("hidden");

    detailHerramientasBody.innerHTML = herramientas
      .map((h) => {
        const cantidad = Number(h.cantidad_total || 0);

        return `
          <tr>
            <td>
              ${escapeHtml(h.nombre || "—")}
            </td>

            <td>
              ${cantidad.toLocaleString("es-UY")}
            </td>
          </tr>
        `;
      })
      .join("");
  } else {
    detailHerramientasWrap.classList.add("hidden");
    detailHerramientasEmpty.classList.remove("hidden");
    detailHerramientasBody.innerHTML = "";
  }

  // =========================================================
  // OBREROS
  // =========================================================

  if (obreros.length) {
    detailObrerosWrap.classList.remove("hidden");
    detailObrerosEmpty.classList.add("hidden");

    detailObrerosBody.innerHTML = obreros
      .map((o) => {
        const nombreCompleto =
          `${o.apellido || ""}, ${o.nombre || ""}`.trim();

        const horas = Number(o.horas_totales || 0);

        return `
          <tr>
            <td>
              ${escapeHtml(nombreCompleto || "—")}
            </td>

            <td>
              ${horas.toLocaleString("es-UY", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}
            </td>
          </tr>
        `;
      })
      .join("");
  } else {
    detailObrerosWrap.classList.add("hidden");
    detailObrerosEmpty.classList.remove("hidden");
    detailObrerosBody.innerHTML = "";
  }

  // =========================================================
  // MAQUINARIA
  // =========================================================

  if (maquinaria.length) {
    detailMaquinariaWrap.classList.remove("hidden");
    detailMaquinariaEmpty.classList.add("hidden");

    detailMaquinariaBody.innerHTML = maquinaria
      .map((m) => {
        return `
          <tr>
            <td>
              ${escapeHtml(m.nombre || "—")}
            </td>

            <td>
              ${escapeHtml(m.marca || "—")}
            </td>

            <td>
              ${formatDate(m.fecha_asignacion)}
            </td>

            <td>
              ${formatDate(m.fecha_retiro)}
            </td>
          </tr>
        `;
      })
      .join("");
  } else {
    detailMaquinariaWrap.classList.add("hidden");
    detailMaquinariaEmpty.classList.remove("hidden");
    detailMaquinariaBody.innerHTML = "";
  }

  // =========================================================
  // ACTIVIDADES DEL CONTRATO
  // =========================================================

  const totalTareas = tareas.length;

  const tareasCompletadas = tareas.filter(
    (tarea) => String(tarea.estado || "").toLowerCase() === "completada"
  );

  const tareasPendientes = tareas.filter(
    (tarea) => String(tarea.estado || "").toLowerCase() !== "completada"
  );

  const totalCompletadas = tareasCompletadas.length;
  const totalPendientes = tareasPendientes.length;

  const ganadoHastaAhora = tareasCompletadas.reduce(
    (total, tarea) => {
      return total + Number(tarea.importe || 0);
    },
    0
  );

  // ---------------------------------------------------------
  // ACTUALIZAR RESUMEN
  // ---------------------------------------------------------

  if (detailTareasTotal) {
    detailTareasTotal.textContent = totalTareas;
  }

  if (detailTareasCompletadas) {
    detailTareasCompletadas.textContent = totalCompletadas;
  }

  if (detailTareasPendientes) {
    detailTareasPendientes.textContent = totalPendientes;
  }

  if (detailTareasGanado) {
    detailTareasGanado.textContent =
      `$ ${ganadoHastaAhora.toLocaleString("es-UY", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })}`;
  }

  // ---------------------------------------------------------
  // ACTIVIDADES COMPLETADAS
  // ---------------------------------------------------------

  if (
    detailTareasCompletadasWrap &&
    detailTareasCompletadasBody &&
    detailTareasCompletadasEmpty
  ) {
    if (tareasCompletadas.length) {
      detailTareasCompletadasWrap.classList.remove("hidden");
      detailTareasCompletadasEmpty.classList.add("hidden");

      detailTareasCompletadasBody.innerHTML =
        tareasCompletadas
          .map((tarea) => {
            const importe = Number(tarea.importe || 0);

            return `
              <tr>
                <td>
                  ${escapeHtml(tarea.descripcion || "—")}
                </td>

                <td>
                  $ ${importe.toLocaleString("es-UY", {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </td>

                <td>
                  ${tarea.fecha_completada
                    ? formatDate(tarea.fecha_completada)
                    : "—"}
                </td>
              </tr>
            `;
          })
          .join("");
    } else {
      detailTareasCompletadasWrap.classList.add("hidden");
      detailTareasCompletadasEmpty.classList.remove("hidden");
      detailTareasCompletadasBody.innerHTML = "";
    }
  }

  // ---------------------------------------------------------
  // ACTIVIDADES PENDIENTES
  // ---------------------------------------------------------

  if (
    detailTareasPendientesWrap &&
    detailTareasPendientesBody &&
    detailTareasPendientesEmpty
  ) {
    if (tareasPendientes.length) {
      detailTareasPendientesWrap.classList.remove("hidden");
      detailTareasPendientesEmpty.classList.add("hidden");

      detailTareasPendientesBody.innerHTML =
  tareasPendientes
    .map((tarea) => {
      const importe = Number(tarea.importe || 0);

      return `
        <tr>
          <td>
            ${escapeHtml(tarea.descripcion || "—")}
          </td>

          <td>
            $ ${importe.toLocaleString("es-UY", {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })}
          </td>

          <td>
            <button
              type="button"
              class="action-btn complete-task-detail"
              data-task-action="complete"
              data-tarea-id="${tarea.id_tarea}"
              data-obra-id="${obra.id_obra}"
              title="Marcar actividad como completada"
            >
            <i class="fas fa-check"></i>
              Completar
            </button>
          </td>
        </tr>
      `;
    })
    .join("");
    } else {
      detailTareasPendientesWrap.classList.add("hidden");
      detailTareasPendientesEmpty.classList.remove("hidden");
      detailTareasPendientesBody.innerHTML = "";
    }
  }

  // =========================================================
  // RECURSOS
  // =========================================================
  // Este bloque se mantiene separado de:
  // - Materiales
  // - Herramientas
  // - Obreros
  // - Maquinaria
  //
  // Solo se utiliza si el HTML tiene:
  // detailRecursosWrap
  // detailRecursosBody
  // detailRecursosEmpty

  if (
    typeof detailRecursosWrap !== "undefined" &&
    detailRecursosWrap
  ) {
    if (recursos.length) {
      detailRecursosWrap.classList.remove("hidden");

      if (
        typeof detailRecursosEmpty !== "undefined" &&
        detailRecursosEmpty
      ) {
        detailRecursosEmpty.classList.add("hidden");
      }

      if (
        typeof detailRecursosBody !== "undefined" &&
        detailRecursosBody
      ) {
        detailRecursosBody.innerHTML = recursos
          .map((r) => {
            return `
              <tr>
                <td>
                  ${escapeHtml(r.nombre || "—")}
                </td>

                <td>
                  ${escapeHtml(r.tipo || "—")}
                </td>

                <td>
                  ${Number(
                    r.cantidad || r.cantidad_total || 0
                  ).toLocaleString("es-UY")}
                </td>
              </tr>
            `;
          })
          .join("");
      }
    } else {
      detailRecursosWrap.classList.add("hidden");

      if (
        typeof detailRecursosEmpty !== "undefined" &&
        detailRecursosEmpty
      ) {
        detailRecursosEmpty.classList.remove("hidden");
      }

      if (
        typeof detailRecursosBody !== "undefined" &&
        detailRecursosBody
      ) {
        detailRecursosBody.innerHTML = "";
      }
    }
  }

  // =========================================================
  // CONFIGURACIÓN DE BOTONES
  // =========================================================

  detailBtnEdit.disabled = false;

  detailBtnDownload.disabled =
    !obra.contrato_nombre_archivo;

  detailBtnDelete.disabled = false;

  detailBtnToggleStatus.disabled = false;

  detailBtnMap.disabled = !obra.direccion;

  detailBtnEdit.onclick = (event) => {
  event.stopPropagation();

  cerrarDetalle();

  abrirConfirmacion({
    title: "Confirmar edición",

    message:
      `¿Querés cargar "${obra.nombre}" ` +
      `en el formulario para editarla?`,

    acceptLabel: "Editar",

    onAccept: async () => {
      try {
        const data = await obtenerDetalleObra(
          Number(obra.id_obra)
        );

        const obraCompleta = {
          ...data.obra,
          tareas: data.tareas || [],
        };

        fillForm(obraCompleta);

        setFeedback(
          `Editando ${obra.nombre}.`,
          "info"
        );
      } catch (error) {
        console.error(error);

        setFeedback(
          error.message ||
            "No se pudieron cargar las actividades.",
          "error"
        );
      }
    },
  });
};

  // =========================================================
  // MAPA
  // =========================================================

  detailBtnMap.onclick = async (event) => {
    event.stopPropagation();

    if (!obra.direccion) {
      return;
    }

    const visible =
      !detailMapSection.classList.contains("hidden");

    if (visible) {
      detailMapSection.classList.add("hidden");
      return;
    }

    try {
      const geo = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(
          obra.direccion
        )}`
      ).then((response) => response.json());

      if (geo.length) {
        const { lat, lon } = geo[0];

        /*
         * Se agrega un pequeño margen al mapa para que
         * el marcador no quede pegado al borde.
         */
        const latNumber = Number(lat);
        const lonNumber = Number(lon);

        const margenLat = 0.005;
        const margenLon = 0.005;

        const bbox = [
          lonNumber - margenLon,
          latNumber - margenLat,
          lonNumber + margenLon,
          latNumber + margenLat,
        ].join(",");

        detailMapIframe.src =
          `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}` +
          `&layer=mapnik&marker=${lat},${lon}`;
      } else {
        detailMapIframe.src =
          "https://www.openstreetmap.org/export/embed.html?bbox=&layer=mapnik";
      }
    } catch (error) {
      console.error(
        "No se pudo localizar la dirección:",
        error
      );

      detailMapIframe.src =
        "https://www.openstreetmap.org/export/embed.html?bbox=&layer=mapnik";
    }

    detailMapSection.classList.remove("hidden");
  };

  // =========================================================
  // CAMBIAR ESTADO DE LA OBRA
  // =========================================================

  detailToggleStatusText.textContent = esActiva
    ? "Finalizar Obra"
    : "Activar Obra";

  detailBtnToggleStatus.className = esActiva
    ? "btn-save"
    : "btn-secondary";

  detailBtnToggleStatus.onclick = (event) => {
    event.stopPropagation();

    cerrarDetalle();

    const nuevoEstado = esActiva ? 0 : 1;
    const accion = esActiva
      ? "finalizar"
      : "activar";

    abrirConfirmacion({
      title: `Confirmar ${accion} de obra`,

      message:
        `¿Estás seguro de que querés ${accion} ` +
        `la obra "${obra.nombre}"?`,

      acceptLabel: esActiva
        ? "Finalizar"
        : "Activar",

      onAccept: async () => {
        try {
          await cambiarEstadoObra(
            obra.id_obra,
            nuevoEstado
          );

          await cargarObras();

          setFeedback(
            `Obra "${obra.nombre}" ${
              nuevoEstado === 1
                ? "activada"
                : "finalizada"
            } con éxito.`,
            "success"
          );
        } catch (error) {
          console.error(error);

          setFeedback(
            error.message ||
              "No se pudo cambiar el estado de la obra.",
            "error"
          );
        }
      },
    });
  };

  // =========================================================
  // BOTÓN DESCARGAR CONTRATO
  // =========================================================

  detailBtnDownload.onclick = async (event) => {
    event.stopPropagation();

    if (!obra.contrato_nombre_archivo) {
      setFeedback(
        "Esta obra no tiene un contrato cargado.",
        "info"
      );
      return;
    }

    try {
      await descargarContrato(obra.id_obra);
    } catch (error) {
      console.error(error);

      setFeedback(
        error.message ||
          "No se pudo descargar el contrato.",
        "error"
      );
    }
  };

  // =========================================================
  // BOTÓN ELIMINAR
  // =========================================================

  detailBtnDelete.onclick = (event) => {
    event.stopPropagation();

    cerrarDetalle();

    abrirConfirmacion({
      title: "Confirmar eliminación",

      message:
        `¿Eliminar la obra "${obra.nombre}"? ` +
        `Esta acción no se puede deshacer.`,

      acceptLabel: "Eliminar",

      onAccept: async () => {
        try {
          if (apiBase && !csrfToken) {
            csrfToken = await obtenerCsrf();
          }

          const data =
            await eliminarObra(obra.id_obra);

          if (obraEnEdicion === obra.id_obra) {
            resetForm();
          }

          await cargarObras();

          setFeedback(
            data.message ||
              "Obra eliminada correctamente.",
            "success"
          );
        } catch (error) {
          console.error(error);

          setFeedback(
            error.message ||
              "No se pudo eliminar la obra.",
            "error"
          );
        }
      },
    });
  };

  // =========================================================
// BOTÓN EDITAR
// =========================================================

detailBtnEdit.onclick = (event) => {
  event.stopPropagation();

  cerrarDetalle();

  abrirConfirmacion({
    title: "Confirmar edición",

    message:
      `¿Querés cargar "${obra.nombre}" ` +
      `en el formulario para editarla?`,

    acceptLabel: "Editar",

    onAccept: async () => {
      try {
        const data = await obtenerDetalleObra(
          Number(obra.id_obra)
        );

        const obraCompleta = {
          ...data.obra,
          tareas: data.tareas || [],
        };

        fillForm(obraCompleta);

        setFeedback(
          `Editando ${obra.nombre}.`,
          "info"
        );
      } catch (error) {
        console.error(error);

        setFeedback(
          error.message ||
            "No se pudieron cargar las actividades.",
          "error"
        );
      }
    },
  });
};

}

async function cambiarEstadoObra(idObra, activo) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      credentials: "include",
      body: JSON.stringify({ id_obra: idObra, activo: activo, accion: "cambiar_estado" }),
    });

    const data = await parseJsonResponse(response, "No se pudo cambiar el estado de la obra.");
    if (!response.ok) {
      throw new Error(data.error || "No se pudo cambiar el estado de la obra.");
    }
    return data;
  }

  return sendDesktopRequest(
    "obras_cambiar_estado",
    { id_obra: idObra, activo: activo },
    "obras_cambiar_estado_response",
  );
}


async function completarTarea(idTarea) {
  if (apiBase) {
    const response = await fetch(`${apiBase}/Obras.php`, {
      method: "POST",

      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },

      credentials: "include",

      body: JSON.stringify({
        accion: "completar_tarea",
        id_tarea: idTarea,
      }),
    });

    const data = await parseJsonResponse(
      response,
      "No se pudo completar la actividad."
    );

    if (!response.ok) {
      throw new Error(
        data.error ||
          "No se pudo completar la actividad."
      );
    }

    return data;
  }

  return sendDesktopRequest(
    "obras_completar_tarea",
    {
      id_tarea: idTarea,
    },
    "obras_completar_tarea_response"
  );
}

function formatDate(value) {
  if (!value) {
    return "Sin fecha";
  }

  const [year, month, day] = value.split("-");
  if (!year || !month || !day || year === "0000") {
    return "Sin fecha";
  }

  return `${day}/${month}/${year}`;
}

function obtenerMensajeSinResultados(busqueda, estado) {
  if (!busqueda && estado === "all") {
    return "No hay obras registradas todavía.";
  }

  if (busqueda && estado !== "all") {
    return "No se encontraron obras para esa búsqueda y estado.";
  }

  if (busqueda) {
    return "No se encontraron obras para esa búsqueda.";
  }

  if (estado === "active") {
    return "No hay obras activas para mostrar.";
  }

  if (estado === "inactive") {
    return "No hay obras inactivas para mostrar.";
  }

  return "No hay obras registradas todavía.";
}

// =========================================================
// FUNCIONES DE ACTIVIDADES DEL CONTRATO
// =========================================================

function agregarTarea() {
  const nuevaTarea = {
    id_tarea: Date.now(),
    id_tarea_origen: null,
    descripcion: "",
    importe: 0,
    estado: "Pendiente",
    fecha_completada: null,
  };

  tareasContrato.push(nuevaTarea);

  renderTareasContrato();

  // Enfocar automáticamente el campo de descripción
  window.setTimeout(() => {
    const input = contratoTareasBody.querySelector(
      `input[data-tarea-id="${nuevaTarea.id_tarea}"]`
    );

    if (input) {
      input.focus();
    }
  }, 50);
}


function renderTareasContrato() {
  if (!contratoTareasBody) {
    return;
  }

  contratoTareasBody.innerHTML = "";

  if (tareasContrato.length === 0) {
    if (tareasEmpty) {
      tareasEmpty.classList.remove("hidden");
    }

    actualizarTotalContrato();
    return;
  }

  if (tareasEmpty) {
    tareasEmpty.classList.add("hidden");
  }

  tareasContrato.forEach((tarea) => {
    const row = document.createElement("tr");

    row.innerHTML = `
      <td>
        <input
          type="text"
          class="task-input"
          data-tarea-id="${tarea.id_tarea}"
          data-field="descripcion"
          value="${escapeHtml(tarea.descripcion)}"
          placeholder="Descripción de la actividad"
        />
      </td>

      <td>
        <input
          type="number"
          class="task-input task-importe"
          data-tarea-id="${tarea.id_tarea}"
          data-field="importe"
          value="${Number(tarea.importe || 0).toFixed(2)}"
          min="0"
          step="0.01"
          placeholder="0.00"
        />
      </td>

      <td>
        <select
          class="task-input"
          data-tarea-id="${tarea.id_tarea}"
          data-field="estado"
        >
          <option value="Pendiente" ${
            tarea.estado === "Pendiente" ? "selected" : ""
          }>
            Pendiente
          </option>

          <option value="Completada" ${
            tarea.estado === "Completada" ? "selected" : ""
          }>
            Completada
          </option>
        </select>
      </td>

      <td>
        <button
          type="button"
          class="action-btn delete-task"
          data-task-action="delete"
          data-tarea-id="${tarea.id_tarea}"
          title="Eliminar actividad"
        >
          <i class="fas fa-trash"></i>
        </button>
      </td>
    `;

    contratoTareasBody.appendChild(row);
  });

  actualizarTotalContrato();
}


function actualizarTotalContrato() {
  if (!totalContrato) {
    return;
  }

  const total = tareasContrato.reduce((suma, tarea) => {
    return suma + Number(tarea.importe || 0);
  }, 0);

  totalContrato.textContent = `$ ${total.toLocaleString("es-UY", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}


// Cambios dentro de la tabla de tareas
if (contratoTareasBody) {
  contratoTareasBody.addEventListener("input", (event) => {
    const input = event.target.closest("[data-tarea-id]");

    if (!input) {
      return;
    }

    const idTarea = Number(input.dataset.tareaId);
    const campo = input.dataset.field;

    const tarea = tareasContrato.find(
      (item) => item.id_tarea === idTarea
    );

    if (!tarea) {
      return;
    }

    if (campo === "descripcion") {
      tarea.descripcion = input.value;
    }

    if (campo === "importe") {
      tarea.importe = Number(input.value || 0);
    }

    actualizarTotalContrato();
  });


  contratoTareasBody.addEventListener("change", (event) => {
    const input = event.target.closest("[data-tarea-id]");

    if (!input) {
      return;
    }

    const idTarea = Number(input.dataset.tareaId);
    const campo = input.dataset.field;

    const tarea = tareasContrato.find(
      (item) => item.id_tarea === idTarea
    );

    if (!tarea) {
      return;
    }

    if (campo === "estado") {
      tarea.estado = input.value;

      if (tarea.estado === "Completada") {
        const hoy = new Date();

        const year = hoy.getFullYear();
        const month = String(hoy.getMonth() + 1).padStart(2, "0");
        const day = String(hoy.getDate()).padStart(2, "0");

        tarea.fecha_completada = `${year}-${month}-${day}`;
      } else {
        tarea.fecha_completada = null;
      }
    }
  });


  contratoTareasBody.addEventListener("click", (event) => {
    const button = event.target.closest(
      "button[data-task-action='delete']"
    );

    if (!button) {
      return;
    }

    const idTarea = Number(button.dataset.tareaId);

    tareasContrato = tareasContrato.filter(
      (tarea) => tarea.id_tarea !== idTarea
    );

    renderTareasContrato();
  });
}

async function obtenerDetalleObra(idObra) {
  if (apiBase) {
    return await fetchJson(
      `${apiBase}/Obras.php?id_obra=${encodeURIComponent(idObra)}&detalle=1`
    );
  }

  return await sendDesktopRequest(
    "obras_detalle",
    { id_obra: idObra },
    "obras_detalle_response"
  );
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
