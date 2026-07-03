# 部署步骤

## 1. 推送到 GitHub

打开 Git Bash，依次执行：

```bash
cd "C:/Users/35003/减肥助手"
git init
git add -A
git commit -m "减脂助手 v1.0"
gh repo create 减脂助手 --public --source=. --remote=origin --push
```

推送后 GitHub Actions 自动部署到 Pages，等2分钟就能在手机上打开。

Pages URL 格式：`https://jinlongyu66.github.io/减脂助手/`

## 2. Supabase 建表

打开 Supabase 项目面板 → SQL Editor，依次执行：

1. 复制 `schema.sql` 全部内容 → 执行
2. 复制 `rpc-api.sql` 全部内容 → 执行

（Supabase 项目跟直播工作台共用一个：`https://xyeecqpbaxzjrbukipyi.supabase.co`）

## 3. 使用

1. 手机浏览器打开 Pages URL
2. 注册账号
3. 填写身体数据
4. 去设置页填 AI API Key（DeepSeek 推荐）
5. 开始用
