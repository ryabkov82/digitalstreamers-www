(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', function () {
    var form = document.getElementById('loginForm');
    if (!form) return;

    var submitBtn = document.getElementById('submitBtn');
    var errorDiv = document.getElementById('errorMessage');
    var errorText = document.getElementById('errorText');

    function setMessage(msg, ok) {
      errorText.textContent = msg;
      errorDiv.hidden = false;
      errorDiv.classList.toggle('is-success', !!ok);
      errorDiv.classList.toggle('is-error', !ok);
      errorDiv.setAttribute('role', ok ? 'status' : 'alert');
    }

    function clearMessage() {
      errorDiv.hidden = true;
      errorText.textContent = '';
      errorDiv.classList.remove('is-success', 'is-error');
    }

    function messageFromPayload(data, fallback) {
      if (!data || typeof data !== 'object') return fallback;
      if (data.message) return String(data.message);
      return fallback;
    }

    form.addEventListener('submit', async function (e) {
      e.preventDefault();

      var emailInput = document.getElementById('email');
      var passwordInput = document.getElementById('password');
      var email = (emailInput.value || '').trim();
      var password = passwordInput.value || '';

      if (!email.includes('@')) {
        setMessage('Пожалуйста, введите корректный email', false);
        emailInput.focus();
        return;
      }
      if (password.length < 6) {
        setMessage('Пароль должен содержать не менее 6 символов', false);
        passwordInput.focus();
        return;
      }

      submitBtn.textContent = 'Подключение...';
      submitBtn.disabled = true;
      clearMessage();

      try {
        var res = await fetch('/api/login', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify({
            email: email,
            password: password,
            device_id: navigator.userAgent,
            timestamp: Date.now()
          })
        });

        var data = await res.json().catch(function () { return {}; });
        var code = data && data.error_code ? String(data.error_code) : '';

        if (res.status === 200) {
          if (data && data.token) {
            localStorage.setItem('authToken', data.token);
          }
          setMessage('Вход выполнен. Перенаправляем…', true);
          window.setTimeout(function () {
            window.location.href = (data && data.redirect) ? data.redirect : '/dashboard';
          }, 800);
          return;
        }

        if (res.status === 423 || code === 'ACCOUNT_LOCKED') {
          setMessage('Аккаунт временно заблокирован. Обратитесь в поддержку.', false);
        } else if (res.status === 429 || code === 'RATE_LIMIT_EXCEEDED') {
          setMessage('Слишком много попыток входа. Попробуйте через 5 минут.', false);
        } else if (res.status === 401 || code === 'INVALID_CREDENTIALS' || code === 'MAINTENANCE_MODE') {
          setMessage(messageFromPayload(data, 'Неверный логин или пароль'), false);
        } else if (res.status >= 500) {
          setMessage('Внутренняя ошибка сервера. Попробуйте позже.', false);
        } else {
          setMessage(messageFromPayload(data, 'Неизвестная ошибка'), false);
        }
      } catch (err) {
        var offline = err && err.name === 'TypeError';
        setMessage(
          offline
            ? 'Ошибка соединения с сервером авторизации'
            : 'Произошла непредвиденная ошибка',
          false
        );
      } finally {
        submitBtn.textContent = 'Войти';
        submitBtn.disabled = false;
        passwordInput.value = '';
      }
    });
  });
})();
