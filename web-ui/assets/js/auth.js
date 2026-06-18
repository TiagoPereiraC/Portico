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
        function updatePill() {
            const pill = document.querySelector('.user-pill');
            const pillName = document.querySelector('.user-pill-name');
            if (pillName) {
                pillName.textContent = nombre;
            } else if (pill) {
                pill.textContent = nombre;
            }
        }
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', updatePill);
        } else {
            updatePill();
        }
        return true;
    }

    function doLogout() {
        sessionStorage.clear();

        if (window.chrome?.webview) {
            window.chrome.webview.postMessage(JSON.stringify({ type: 'logout' }));
            return;
        }

        if (isHttp) {
            var apiBase = resolveApiBase();
            fetch(apiBase + '/logout.php', {
                method: 'POST',
                credentials: 'include'
            }).catch(function () {}).finally(function () {
                window.location.href = 'Login.html';
            });
        } else {
            window.location.href = 'Login.html';
        }
    }

    // Ocultar la página inmediatamente para evitar el parpadeo de contenido protegido
    document.documentElement.style.visibility = 'hidden';

    // Interceptar clicks en cualquier enlace a Login.html (botón Salir)
    document.addEventListener('click', function (e) {
        var link = e.target.closest('a[href="Login.html"]');
        if (!link) return;
        e.preventDefault();
        doLogout();
    });

    if (!isHttp) {
        // En modo escritorio, el control de sesión suele ser manejado por la app contenedora
        // pero mantenemos la visibilidad la cual será controlada por el cargador de la app
        document.documentElement.style.visibility = 'visible';
        return;
    }

    const apiBase = resolveApiBase();
    var timeoutId = window.setTimeout(function () {
        window.location.replace('Login.html');
    }, 10000);

    fetch(apiBase + '/session.php', { credentials: 'include' })
        .then(function (res) { return res.json(); })
        .then(function (data) {
            window.clearTimeout(timeoutId);
            if (data && data.autenticado) {
                sessionStorage.setItem('user_id', String(data.user_id));
                sessionStorage.setItem('rol', data.rol);
                sessionStorage.setItem('nombre', data.nombre);
                
                if (applySession(data.rol, data.nombre)) {
                    document.documentElement.style.visibility = 'visible';
                }
            } else {
                window.location.replace('Login.html');
            }
        })
        .catch(function () {
            window.clearTimeout(timeoutId);
            window.location.replace('Login.html');
        });
})();
