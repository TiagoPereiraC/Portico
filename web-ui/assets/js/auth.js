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
    const script = document.currentScript;
    const required = script?.dataset?.role;
    const isHttp = window.location.protocol.startsWith('http');

    function resolveApiBase() {
        if (!isHttp) return null;
        const path = window.location.pathname;
        const idx = path.lastIndexOf('/web-ui/');
        if (idx !== -1) {
            return window.location.origin + path.substring(0, idx) + '/api';
        }
        return window.location.origin + '/api';
    }

    function applySession(rol, nombre) {
        if (required && rol !== required) {
            window.location.replace(rol === 'Capataz' ? 'Asistencia.html' : 'Login.html');
            return false;
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
        return true;
    }

    const rolStored = sessionStorage.getItem('rol') || '';
    const nombreStored = sessionStorage.getItem('nombre') || 'Usuario';

    if (rolStored) {
        applySession(rolStored, nombreStored);
        return;
    }

    if (!isHttp) {
        window.location.replace('Login.html');
        return;
    }

    const apiBase = resolveApiBase();
    fetch(apiBase + '/session.php', { credentials: 'include' })
        .then(function (res) { return res.json(); })
        .then(function (data) {
            if (data && data.autenticado) {
                sessionStorage.setItem('user_id', String(data.user_id));
                sessionStorage.setItem('rol', data.rol);
                sessionStorage.setItem('nombre', data.nombre);
                applySession(data.rol, data.nombre);
            } else {
                window.location.replace('Login.html');
            }
        })
        .catch(function () {
            window.location.replace('Login.html');
        });
})();
