document.addEventListener('DOMContentLoaded', () => {

    cargarObreros();

    document
        .getElementById('btnBuscar')
        .addEventListener('click', buscarConsultas);
});

const feedback = document.getElementById('feedback');

function mostrarFeedback(mensaje, tipo) {
    feedback.innerHTML = `<i class="fas ${tipo === 'error' ? 'fa-circle-exclamation' : tipo === 'success' ? 'fa-circle-check' : 'fa-triangle-exclamation'}"></i><span>${escapeHtml(mensaje)}</span>`;
    feedback.className = `feedback-msg ${tipo}`;
    feedback.classList.remove('hidden');
}

function ocultarFeedback() {
    feedback.classList.add('hidden');
}

async function cargarObreros() {

    try {

        ocultarFeedback();

        const response =
            await fetch('../api/obtener_obrero.php');

        const data =
            await response.json();

        if (!data.success) {
            throw new Error(data.error);
        }

        const select =
            document.getElementById('obrero');

        data.obreros.forEach(obrero => {

            const option =
                document.createElement('option');

            option.value =
                obrero.id_obrero;

            option.textContent =
                `${obrero.nombre} ${obrero.apellido ?? ''}`;

            select.appendChild(option);
        });

    } catch (error) {

        console.error(error);

        mostrarFeedback('Error cargando obreros.', 'error');
    }
}

async function buscarConsultas() {

    const idObrero =
        document.getElementById('obrero').value;

    const fechaDesde =
        document.getElementById('fecha_desde').value;

    const fechaHasta =
        document.getElementById('fecha_hasta').value;

    if (!idObrero && !fechaDesde && !fechaHasta) {
        mostrarFeedback('Seleccione al menos un obrero o un período.', 'warning');
        return;
    }

    try {

        ocultarFeedback();

        const response = await fetch(
            `../api/consultas.php?id_obrero=${idObrero || 0}&fecha_desde=${fechaDesde}&fecha_hasta=${fechaHasta}`
        );

        const data = await response.json();

        if (!data.success) {
            throw new Error(data.error);
        }

        mostrarResumen(data.resumen);
        mostrarRegistros(data.registros);

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

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
