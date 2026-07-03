#!/bin/bash
cd "C:/Users/35003/减肥助手"
cp index.html index.html.bak2

# 1. Add admin storage for register (after sessionStorage.setItem('fit_token', TOKEN))
sed -i '/sessionStorage.setItem.*fit_token.*TOKEN.*loginPage.*hidden/a\    sessionStorage.setItem('\''fit_admin'\'', IS_ADMIN ? '\''true'\'' : '\''false'\'');' index.html

# 2. Add admin button in settings tab (before 退出登录 line)
sed -i '/<span>退出登录<\/span>/i\        <div class="settings-item" id="adminBtn" style="border:none;display:none">\n          <span>👑 用户管理</span>\n          <button class="btn-sm" style="background:#8b5cf6;color:#fff;border:none;border-radius:6px" onclick="showAdmin()">管理</button>\n        </div>' index.html

# 3. Add admin tab bar item (before </nav>)
sed -i 's|<div class="tab-item" data-tab="Settings">|  <div class="tab-item" id="adminTab" data-tab="AdminPanel" style="display:none"><span class="icon">👑</span>管理</div>\n    <div class="tab-item" data-tab="Settings">|' index.html

echo "Basic patches applied"
