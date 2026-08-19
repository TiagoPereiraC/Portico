(function () {

    const feedback = document.getElementById('feedback');

    function resolveApiBase() {
        if (!window.location.protocol.startsWith('http')) {
            return null;
        }

        const path = window.location.pathname;
        const idx = path.lastIndexOf('/web-ui/');
        if (idx !== -1) {
            return window.location.origin + path.substring(0, idx) + '/api';
        }
        return window.location.origin + '/api';
    }

    const apiBase = resolveApiBase();

    function mostrarFeedback(mensaje, tipo) {
        if (!feedback) {
            return;
        }

        feedback.textContent = mensaje;
        feedback.className = 'feedback ' + tipo;
    }

    function triggerDownload(blob, nombre) {
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = nombre;
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
    }

    function getFileNameFromDisposition(disposition) {
        if (!disposition) {
            return null;
        }

        const match = /filename="?([^";]+)"?/i.exec(disposition);
        return match ? match[1] : null;
    }

    function fechaActual() {
        const ahora = new Date();
        const pad = (n) => String(n).padStart(2, '0');
        return `${ahora.getFullYear()}${pad(ahora.getMonth() + 1)}${pad(ahora.getDate())}_${pad(ahora.getHours())}${pad(ahora.getMinutes())}${pad(ahora.getSeconds())}`;
    }

    async function exportar(entidad) {

        if (!apiBase) {
            mostrarFeedback('Exportación no disponible en este entorno.', 'error');
            return;
        }

        try {

            mostrarFeedback('Generando exportación...', 'info');

            const params = new URLSearchParams({ entidad });
            const response = await fetch(`${apiBase}/exportar_csv.php?${params.toString()}`, {
                credentials: 'include'
            });

            if (!response.ok) {
                const data = await response.json().catch(() => ({}));
                throw new Error(data.error || 'No se pudo exportar.');
            }

            const blob = await response.blob();
            const nombre = getFileNameFromDisposition(response.headers.get('Content-Disposition'))
                || (entidad === 'todas' ? `portico_export_${fechaActual()}.zip` : `${entidad}.csv`);

            triggerDownload(blob, nombre);
            mostrarFeedback('Exportación generada correctamente.', 'success');

        } catch (error) {

            console.error(error);
            mostrarFeedback(error.message || 'Error al exportar.', 'error');
        }
    }

    document.querySelectorAll('[data-entidad]').forEach((card) => {
        card.addEventListener('click', (event) => {
            event.preventDefault();
            exportar(card.dataset.entidad);
        });
    });

})();
