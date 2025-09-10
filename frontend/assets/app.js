// frontend/assets/app.js
document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('loginForm');
    const submitBtn = document.getElementById('submitBtn');
    const errorDiv = document.getElementById('errorMessage');
    const errorText = document.getElementById('errorText');
  
    const setError = (msg, ok = false) => {
      errorText.textContent = msg;
      errorDiv.style.display = 'block';
      errorDiv.style.backgroundColor = ok ? 'rgba(100,255,100,0.2)' : 'rgba(255,100,100,0.2)';
      errorDiv.style.borderColor = ok ? 'rgba(100,255,100,0.5)' : 'rgba(255,100,100,0.5)';
    };
  
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
  
      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value;
  
      if (!email.includes('@')) return setError('Пожалуйста, введите корректный email');
      if (password.length < 6)  return setError('Пароль должен содержать не менее 6 символов');
  
      submitBtn.textContent = 'Подключение...';
      submitBtn.disabled = true;
      errorDiv.style.display = 'none';
  
      try {
        await new Promise(r => setTimeout(r, 800 + Math.random() * 700));
  
        const res = await fetch('/api/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
          body: JSON.stringify({ email, password, device_id: navigator.userAgent, timestamp: Date.now() })
        });
  
        const data = await res.json().catch(() => ({}));
  
        console.log('Server response:', { status: res.status, headers: Object.fromEntries(res.headers.entries()), data });
  
        if (res.status === 200) {
          setError('✅ Проверка учетных данных завершена', true);
        } else if (res.status === 401) {
          setError((data && data.message) ? `${data.message} (код: ${data.error_code})` : 'Неавторизован');
        } else if (res.status === 423) {
          setError('Аккаунт временно заблокирован. Обратитесь в поддержку.');
        } else if (res.status === 429) {
          setError('Слишком много попыток входа. Попробуйте через 5 минут.');
        } else if (res.status >= 500) {
          setError('Внутренняя ошибка сервера. Попробуйте позже.');
        } else {
          setError((data && data.message) || 'Неизвестная ошибка');
        }
      } catch (err) {
        setError(err && err.name === 'TypeError' ? 'Ошибка соединения с сервером авторизации' : 'Произошла непредвиденная ошибка');
        console.error('Network error:', err);
      } finally {
        submitBtn.textContent = 'Войти';
        submitBtn.disabled = false;
        console.log('Login attempt:', { email, timestamp: new Date().toISOString(), userAgent: navigator.userAgent });
      }
    });
  
    // Часы в подвале
    const timeEl = document.getElementById('currentTime');
    if (timeEl) setInterval(() => { timeEl.textContent = new Date().toLocaleString(); }, 1000);

    // Подтягиваем имя/город узла
    const nameEl = document.getElementById('serverName');
    if (nameEl) {
        fetch('/api/status', { cache: 'no-store' })
        .then(r => r.json())
        .then(d => {
            // ожидаем поля из nginx: name, city
            nameEl.textContent = d && (d.name || d.hostname)
            ? [d.name, d.city].filter(Boolean).join(' · ')
            : window.location.host;
        })
        .catch(() => { nameEl.textContent = window.location.host; });
    }    
  });
  