/**
 * auth.js — Control de acceso basado en rol
 *
 * Uso en páginas de solo Admin:
 *   <script src="assets/js/auth.js" data-role="Administrador"></script>
 *
 * Uso en páginas de Capataz (sin restricción de rol):
 *   <script src="assets/js/auth.js"></script>
 */

(function () {
    const rol    = sessionStorage.getItem('rol')    || '';
    const nombre = sessionStorage.getItem('nombre') || 'Usuario';

    const required = document.currentScript?.dataset?.role;
    if (required && rol !== required) {
        window.location.replace(rol === 'Capataz' ? 'Asistencia.html' : 'Login.html');
        return;
    }

    document.addEventListener('DOMContentLoaded', function () {
        const pill = document.querySelector('.user-pill');
        const pillName = document.querySelector('.user-pill-name');
        if (pillName) {
            pillName.textContent = nombre;
        } else if (pill) {
            pill.textContent = nombre;
        }
    });
})();
