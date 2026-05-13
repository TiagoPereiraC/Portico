(function (global) {
    const isDesktop = Boolean(global.chrome?.webview);
    const isBrowserHttp = global.location.protocol.startsWith('http');
    const pendingRequests = new Map();
    let desktopListenerRegistered = false;
    let csrfTokenPromise = null;

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
                pending.reject(new Error(data.error || 'No se pudo completar la operación.'));
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

    async function getCsrfToken() {
        if (!isBrowserHttp) {
            throw new Error('Abrí esta pantalla desde un servidor local PHP para gestionar usuarios en navegador.');
        }

        if (!csrfTokenPromise) {
            csrfTokenPromise = fetch(`${apiBase}/csrf.php`, {
                credentials: 'include'
            }).then(async function (response) {
                const data = await parseJsonResponse(response, 'No se pudo obtener el token de seguridad.');

                if (!response.ok || !data.token) {
                    throw new Error(data.error || 'No se pudo obtener el token de seguridad.');
                }

                return data.token;
            }).catch(function (error) {
                csrfTokenPromise = null;
                throw error;
            });
        }

        return csrfTokenPromise;
    }

    async function requestBrowser(method, payload, query) {
        if (!isBrowserHttp) {
            throw new Error('Abrí esta pantalla desde un servidor local PHP para gestionar usuarios en navegador.');
        }

        const url = new URL(`${apiBase}/usuarios.php`);
        if (query) {
            Object.entries(query).forEach(function ([key, value]) {
                if (value !== undefined && value !== null && value !== '') {
                    url.searchParams.set(key, String(value));
                }
            });
        }

        const headers = {};
        const options = {
            method,
            credentials: 'include',
            headers
        };

        if (method !== 'GET') {
            headers['Content-Type'] = 'application/json';
            headers['X-CSRF-Token'] = await getCsrfToken();
            options.body = JSON.stringify(payload || {});
        }

        const response = await fetch(url, options);
        const data = await parseJsonResponse(response, 'No se pudo completar la operación.');

        if (!response.ok) {
            if (response.status === 403) {
                csrfTokenPromise = null;
            }
            throw new Error(data.error || 'No se pudo completar la operación.');
        }

        return data;
    }

    function requestDesktop(type, payload) {
        registerDesktopListener();

        return new Promise(function (resolve, reject) {
            const requestId = nextRequestId(type);
            pendingRequests.set(requestId, { resolve, reject });

            global.chrome.webview.postMessage(JSON.stringify({
                type,
                requestId,
                ...(payload || {})
            }));
        });
    }

    global.userApi = {
        isDesktop,
        listUsers: function () {
            return isDesktop ? requestDesktop('users_list') : requestBrowser('GET');
        },
        getUser: function (idUsuario) {
            return isDesktop
                ? requestDesktop('user_get', { id_usuario: idUsuario })
                : requestBrowser('GET', null, { id: idUsuario });
        },
        createUser: function (payload) {
            return isDesktop ? requestDesktop('user_create', payload) : requestBrowser('POST', payload);
        },
        updateUser: function (payload) {
            return isDesktop ? requestDesktop('user_update', payload) : requestBrowser('PUT', payload);
        },
        deleteUser: function (idUsuario) {
            return isDesktop
                ? requestDesktop('user_delete', { id_usuario: idUsuario })
                : requestBrowser('DELETE', { id_usuario: idUsuario });
        }
    };
})(window);