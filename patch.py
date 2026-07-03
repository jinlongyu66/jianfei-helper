import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Add IS_ADMIN after TOKEN = r.token in doLogin
old = 'TOKEN = r.token;\n    sessionStorage.setItem(\'fit_token\', TOKEN);\n    document.getElementById(\'loginPage\')'
new = 'TOKEN = r.token;\n    IS_ADMIN = r.is_admin || false;\n    sessionStorage.setItem(\'fit_token\', TOKEN);\n    sessionStorage.setItem(\'fit_admin\', IS_ADMIN ? \'true\' : \'false\');\n    document.getElementById(\'loginPage\')'
content = content.replace(old, new)

# Fix 2: Also update doRegister function (second TOKEN = r.token)
old2 = 'sessionStorage.setItem(\'fit_token\', TOKEN);\n    document.getElementById(\'loginPage\').classList.add(\'hidden\');\n    document.getElementById(\'mainApp\').classList.remove(\'hidden\');\n    toast(\'注册成功！请填写身体数据\');'
new2 = 'sessionStorage.setItem(\'fit_token\', TOKEN);\n    IS_ADMIN = r.is_admin || false;\n    sessionStorage.setItem(\'fit_admin\', IS_ADMIN ? \'true\' : \'false\');\n    document.getElementById(\'loginPage\').classList.add(\'hidden\');\n    document.getElementById(\'mainApp\').classList.remove(\'hidden\');\n    toast(\'注册成功！请填写身体数据\');'
content = content.replace(old2, new2)

# Fix 3: Add admin button to settings (before "退出登录")
old3 = '<span>退出登录</span>\n          <button class="btn-sm" style="background:var(--red);color:#fff;border:none;border-radius:6px" onclick="logout()">退出</button>'
new3 = '<span>退出登录</span>\n          <button class="btn-sm" style="background:var(--red);color:#fff;border:none;border-radius:6px" onclick="logout()">退出</button>\n        </div>\n        <div class="settings-item" id="adminBtn" style="border:none;display:none">\n          <span>👑 用户管理</span>\n          <button class="btn-sm" style="background:#8b5cf6;color:#fff;border:none;border-radius:6px" onclick="showAdmin()">管理</button>'
content = content.replace(old3, new3)

# Fix 4: Add admin panel HTML before closing </div> of mainApp
old4 = '  </div>\n\n  <!-- Bottom Tab Bar -->'
admin_panel = '''
  <!-- Admin Panel -->
  <div id="adminPanel" class="tab-content hidden">
    <div class="card"><h3>👑 用户管理</h3><div id="adminUserList">加载中...</div></div>
    <div class="card">
      <h3>操作</h3>
      <div class="form-group"><label>用户ID</label><input id="adminUserId" type="number"></div>
      <div class="form-group"><label>新密码（留空不修改）</label><input id="adminNewPw" type="text" placeholder="留空则不修改密码"></div>
      <button class="btn-full" style="background:#8b5cf6;margin-bottom:8px" onclick="adminResetPw()">🔑 重置密码</button>
      <button class="btn-full" style="background:#ef4444" onclick="adminDeleteUser()">🗑️ 删除用户</button>
    </div>
    <button class="btn-full" style="background:var(--text2);margin:12px 0" onclick="switchTab(\'Settings\')">← 返回设置</button>
  </div>
'''
content = content.replace(old4, admin_panel + '\n' + old4)

# Fix 5: Add admin tab bar item
old5 = '<div class="tab-item" data-tab="Weight"><span class="icon">📊</span>体重</div>'
new5 = '<div class="tab-item" data-tab="Weight"><span class="icon">📊</span>体重</div>\n    <div class="tab-item" data-tab="Settings"><span class="icon">⚙️</span>设置</div>'
content = content.replace(old5, new5)

# Fix 6: Remove duplicate settings tab bar item (old one needs to be updated)
old6 = '<div class="tab-item" data-tab="Settings"><span class="icon">⚙️</span>设置</div>\n  </nav>'
new6 = '<div class="tab-item" id="adminTab" data-tab="AdminPanel" style="display:none"><span class="icon">👑</span>管理</div>\n  </nav>'
content = content.replace(old6, new6)

# Fix 7: Add admin JS functions before the `</script>` tag
admin_js = '''
// =========================== ADMIN ===========================
function showAdmin() {
  document.querySelectorAll('.tab-content').forEach(el => el.classList.add('hidden'));
  document.getElementById('adminPanel').classList.remove('hidden');
  document.querySelectorAll('.tab-item').forEach(el => el.classList.remove('active'));
  document.getElementById('adminTab').classList.add('active');
  loadAdminUsers();
}

async function loadAdminUsers() {
  try {
    const users = await callRpc('fit_admin_list_users', { tok: TOKEN });
    if (users && !users.error) {
      document.getElementById('adminUserList').innerHTML = users.map(u => `
        <div class="food-item">
          <span>#${u.id} ${u.username} ${u.is_admin ? '👑' : ''}</span>
          <span style="font-size:12px;color:var(--text2)">${u.weight||'?'}kg | ${u.created_at?.slice(0,10)||''}</span>
        </div>
      `).join('');
    } else {
      document.getElementById('adminUserList').innerHTML = '<div style="color:var(--red)">' + (users?.error || '加载失败') + '</div>';
    }
  } catch(e) { document.getElementById('adminUserList').innerHTML = '<div style="color:var(--red)">加载失败</div>'; }
}

async function adminResetPw() {
  const uid = parseInt(document.getElementById('adminUserId').value);
  const pw = document.getElementById('adminNewPw').value.trim();
  if (!uid) { toast('请输入用户ID', true); return; }
  if (!pw) { toast('请输入新密码', true); return; }
  try {
    const r = await callRpc('fit_admin_reset_pw', { tok: TOKEN, target_id: uid, new_pwd: pw });
    if (r.ok) toast('密码已重置');
    else toast(r.error, true);
  } catch(e) { toast(e.message, true); }
}

async function adminDeleteUser() {
  const uid = parseInt(document.getElementById('adminUserId').value);
  if (!uid) { toast('请输入用户ID', true); return; }
  if (!confirm('确定删除用户 #' + uid + '？此操作不可撤销！')) return;
  try {
    const r = await callRpc('fit_admin_delete_user', { tok: TOKEN, target_id: uid });
    if (r.ok) { toast('用户已删除'); loadAdminUsers(); }
    else toast(r.error, true);
  } catch(e) { toast(e.message, true); }
}
'''

content = content.replace('</script>', admin_js + '\n</script>')

# Fix 8: Show admin tab & button if admin
init_part = '''
  // Show admin features
  if (IS_ADMIN) {
    var ab = document.getElementById('adminBtn');
    var at = document.getElementById('adminTab');
    if (ab) ab.style.display = 'block';
    if (at) at.style.display = 'flex';
  }
'''
content = content.replace('  renderDashboard();\n}', '  renderDashboard();\n' + init_part + '\n}')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print('All patches applied successfully!')
