#!/usr/bin/env bash
# 啟英高中園遊會線上預購系統 — 專案自動建立腳本
# 用法：bash setup.sh [project-name]
# 完成後：cd fair-preorder && npm install && npm run dev

set -e
PROJECT="${1:-fair-preorder}"

if [ -d "$PROJECT" ]; then
  echo "❌ 資料夾 '$PROJECT' 已存在，請改名或先刪除"
  exit 1
fi

echo "📁 建立 $PROJECT ..."
mkdir -p "$PROJECT"
cd "$PROJECT"
mkdir -p app/api/storage app/api/pin lib

# ─────────── package.json ───────────
cat > package.json <<'EOF'
{
  "name": "fair-preorder",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@upstash/redis": "^1.34.3",
    "bcryptjs": "^2.4.3",
    "next": "14.2.18",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.15",
    "typescript": "^5.6.3"
  }
}
EOF

# ─────────── tsconfig.json ───────────
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": false,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# ─────────── next.config.mjs ───────────
cat > next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {};
export default nextConfig;
EOF

# ─────────── tailwind.config.ts ───────────
cat > tailwind.config.ts <<'EOF'
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: { extend: {} },
  plugins: [],
};
export default config;
EOF

# ─────────── postcss.config.mjs ───────────
cat > postcss.config.mjs <<'EOF'
export default {
  plugins: { tailwindcss: {}, autoprefixer: {} },
};
EOF

# ─────────── .gitignore ───────────
cat > .gitignore <<'EOF'
node_modules/
.next/
out/
.env
.env.local
.env.*.local
*.log
.DS_Store
.vercel
next-env.d.ts
EOF

# ─────────── .env.example ───────────
cat > .env.example <<'EOF'
# Upstash Redis (https://console.upstash.com)
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=

# 全校管理員密碼（首頁登入時輸入這個進入全校總覽）
SUPER_PIN=all2025
EOF

# ─────────── app/globals.css ───────────
cat > app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body { height: 100%; }
body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
  font-family: ui-sans-serif, system-ui, "PingFang TC", "Noto Sans TC", sans-serif;
}
EOF

# ─────────── app/layout.tsx ───────────
cat > app/layout.tsx <<'EOF'
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "啟英高中園遊會 · 線上預購",
  description: "114學年度校慶暨母親節感恩 · 5月7日（四）",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-Hant"><body>{children}</body></html>
  );
}
EOF

# ─────────── lib/redis.ts ───────────
cat > lib/redis.ts <<'EOF'
import { Redis } from "@upstash/redis";
export const redis = Redis.fromEnv();
EOF

# ─────────── lib/storage.ts ───────────
cat > lib/storage.ts <<'EOF'
"use client";

// Mimics the window.storage interface so the page code stays close to the
// original Claude artifact. Talks to /api/storage on the server side.

export const storage = {
  async get(key: string): Promise<{ key: string; value: string } | null> {
    const r = await fetch(`/api/storage?key=${encodeURIComponent(key)}`);
    if (!r.ok) return null;
    const data = await r.json();
    if (data.value === null || data.value === undefined) return null;
    return { key, value: data.value };
  },
  async set(key: string, value: string) {
    const r = await fetch("/api/storage", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key, value }),
    });
    if (!r.ok) throw new Error("storage.set failed");
    return { key, value };
  },
  async delete(key: string) {
    const r = await fetch(`/api/storage?key=${encodeURIComponent(key)}`, { method: "DELETE" });
    return { key, deleted: r.ok };
  },
};

export const pinApi = {
  async list(): Promise<Record<string, boolean>> {
    const r = await fetch("/api/pin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "list" }),
    });
    if (!r.ok) return {};
    const data = await r.json();
    return data.pins ?? {};
  },
  async set(boothId: string, pin: string): Promise<boolean> {
    const r = await fetch("/api/pin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "set", boothId, pin }),
    });
    return r.ok;
  },
  async verify(boothId: string, pin: string): Promise<boolean> {
    const r = await fetch("/api/pin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "verify", boothId, pin }),
    });
    if (!r.ok) return false;
    const data = await r.json();
    return !!data.ok;
  },
  async reset(boothId: string, superPin: string): Promise<boolean> {
    const r = await fetch("/api/pin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "reset", boothId, superPin }),
    });
    return r.ok;
  },
};
EOF

# ─────────── app/api/storage/route.ts ───────────
cat > app/api/storage/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { redis } from "@/lib/redis";

export const dynamic = "force-dynamic";

// Block direct access to the PIN keyspace via this generic endpoint.
const isAllowedKey = (k: string) => !k.startsWith("pin:") && k !== "pins:index";

export async function GET(req: Request) {
  const url = new URL(req.url);
  const key = url.searchParams.get("key");
  if (!key) return NextResponse.json({ error: "key required" }, { status: 400 });
  if (!isAllowedKey(key)) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  const value = await redis.get<string>(key);
  return NextResponse.json({ key, value: value ?? null });
}

export async function PUT(req: Request) {
  const { key, value } = await req.json();
  if (!key) return NextResponse.json({ error: "key required" }, { status: 400 });
  if (!isAllowedKey(key)) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  await redis.set(key, value);
  return NextResponse.json({ ok: true });
}

export async function DELETE(req: Request) {
  const url = new URL(req.url);
  const key = url.searchParams.get("key");
  if (!key) return NextResponse.json({ error: "key required" }, { status: 400 });
  if (!isAllowedKey(key)) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  await redis.del(key);
  return NextResponse.json({ ok: true });
}
EOF

# ─────────── app/api/pin/route.ts ───────────
cat > app/api/pin/route.ts <<'EOF'
import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { redis } from "@/lib/redis";

export const dynamic = "force-dynamic";

const PIN_KEY = (id: string) => `pin:${id}`;
const PIN_INDEX = "pins:index";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { action, boothId, pin, superPin } = body || {};
  const SUPER_PIN = process.env.SUPER_PIN || "all2025";

  if (action === "list") {
    const ids = ((await redis.smembers(PIN_INDEX)) as string[]) || [];
    const pins: Record<string, boolean> = {};
    ids.forEach((id) => (pins[id] = true));
    return NextResponse.json({ pins });
  }

  if (action === "set") {
    if (!boothId || !pin) return NextResponse.json({ error: "missing" }, { status: 400 });
    if (!/^\d{4}$/.test(String(pin))) return NextResponse.json({ error: "pin must be 4 digits" }, { status: 400 });
    const hash = await bcrypt.hash(String(pin), 8);
    await redis.set(PIN_KEY(boothId), hash);
    await redis.sadd(PIN_INDEX, boothId);
    return NextResponse.json({ ok: true });
  }

  if (action === "verify") {
    if (!boothId || !pin) return NextResponse.json({ ok: false });
    const hash = await redis.get<string>(PIN_KEY(boothId));
    if (!hash) return NextResponse.json({ ok: false, reason: "no-pin-set" });
    const ok = await bcrypt.compare(String(pin), hash);
    return NextResponse.json({ ok });
  }

  if (action === "reset") {
    if (superPin !== SUPER_PIN) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
    if (!boothId) return NextResponse.json({ error: "missing" }, { status: 400 });
    await redis.del(PIN_KEY(boothId));
    await redis.srem(PIN_INDEX, boothId);
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "unknown action" }, { status: 400 });
}
EOF

# ─────────── app/page.tsx (主應用) ───────────
# 從 Claude artifact 移植，重點變動：
#   1) 加 "use client" 與 import { storage, pinApi }
#   2) window.storage.* → storage.*（第三個 shared 參數移除）
#   3) PIN 相關全部走 pinApi（不再有 PINS_KEY 在客端）
cat > app/page.tsx <<'EOF'
"use client";

import { useState, useEffect, useCallback } from "react";
import { storage, pinApi } from "@/lib/storage";

const BOOTHS_DEFAULT = [
  { id:"b莊敬平台", num:"莊敬平台", cls:"學生會", grp:"學生會", name:"蘇在哪", items:[
    {name:"提拉米蘇",price:50},{name:"乾冰汽水",price:30}]},
  { id:"b29", num:"29", cls:"餐管二甲", grp:"餐管科", name:"買一下吧", items:[
    {name:"香腸",price:25},{name:"炸雞排",price:55},{name:"炸薯條",price:35},{name:"茶葉蛋",price:20}]},
  { id:"b26", num:"26", cls:"餐管二戊", grp:"餐管科", name:"戊糕厚呷", items:[
    {name:"雞蛋糕",price:30},{name:"叭噗冰淇淋",price:40}]},
  { id:"b27", num:"27", cls:"餐管一甲", grp:"餐管科", name:"滋本主憶", items:[
    {name:"乾冰汽水",price:30},{name:"麻糬",price:35}]},
  { id:"b28", num:"28", cls:"餐管一丙", grp:"餐管科", name:"炙燒冰淇淋銅鑼燒", items:[
    {name:"炙燒冰淇淋銅鑼燒",price:60},{name:"乾冰汽水",price:30},{name:"射氣球",price:20}]},
  { id:"b30", num:"30", cls:"餐管一戊", grp:"餐管科", name:"禎的夯爆了", items:[
    {name:"麻辣串串",price:40},{name:"義式舒肥雞胡麻冷麵",price:65},{name:"冷飲",price:25}]},
  { id:"b25", num:"25", cls:"實餐一甲", grp:"餐管科", name:"好麻吉", items:[
    {name:"麻吉",price:30},{name:"烤布蕾",price:45},{name:"冬瓜茶",price:25}]},
  { id:"b13", num:"13", cls:"電商一甲", grp:"商管群", name:"God電", items:[
    {name:"舒服雷(飲料)",price:30},{name:"滷味",price:40},{name:"香腸",price:25},{name:"叭噗冰淇淋",price:40}]},
  { id:"b14", num:"14", cls:"資處二戊", grp:"商管群", name:"金焦時刻", items:[
    {name:"焦糖布蕾",price:50}]},
  { id:"b3", num:"3", cls:"時尚一甲戊", grp:"時尚科", name:"湘約冠軍杜拜", items:[
    {name:"現切芭樂",price:30},{name:"杜拜巧克力",price:55},{name:"關東煮",price:40},{name:"冰沙",price:35}]},
  { id:"b4", num:"4", cls:"實髮容一甲", grp:"時尚科", name:"少女彈珠汽水", items:[
    {name:"彈珠汽水",price:30},{name:"水果飲料",price:35}]},
  { id:"b7", num:"7", cls:"僑時一二甲", grp:"時尚科", name:"飲茶園地", items:[
    {name:"飲料",price:30}]},
  { id:"b5", num:"5", cls:"時尚二甲乙", grp:"時尚科", name:"阿美紅茶冰", items:[
    {name:"美味飲料",price:30},{name:"古早味冬紅綠",price:35},{name:"彈珠汽水",price:30}]},
  { id:"b6", num:"6", cls:"時尚二戊髮容二", grp:"時尚科", name:"雅蓁諺炒可愛", items:[
    {name:"炒泡麵",price:35},{name:"可愛氣球",price:20}]},
  { id:"b15", num:"15", cls:"資一戊", grp:"資訊科", name:"越吃越上癮", items:[
    {name:"炒泡麵",price:35}]},
  { id:"b16", num:"16", cls:"資二甲戊", grp:"資訊科", name:"冰涼汽水站", items:[
    {name:"汽水",price:25}]},
  { id:"b31", num:"31", cls:"普通三甲", grp:"普通科", name:"K3", items:[
    {name:"汽水",price:25},{name:"蔥油餅",price:35},{name:"茶葉蛋",price:20}]},
  { id:"b32", num:"32", cls:"普通二己", grp:"普通科", name:"進來坐坐", items:[
    {name:"乾冰汽水",price:30},{name:"香腸",price:25},{name:"辣炒年糕",price:40}]},
  { id:"b33", num:"33", cls:"普通二甲戊", grp:"普通科", name:"小食販賣部", items:[
    {name:"炒泡麵",price:35},{name:"豆花",price:35},{name:"烤棉花糖",price:20}]},
  { id:"b12", num:"12", cls:"應外二戊", grp:"外語群", name:"完蛋了!好香", items:[
    {name:"蛋香小食",price:35}]},
  { id:"b11", num:"11", cls:"應日三戊", grp:"外語群", name:"何意味?真的假的", items:[
    {name:"日式小食",price:35}]},
  { id:"b21", num:"21", cls:"室設一戊/廣設一甲", grp:"設計群", name:"嬰兒之玖冰成癮", items:[
    {name:"冰沙",price:35},{name:"冰淇淋",price:40},{name:"糖果",price:20}]},
  { id:"b22", num:"22", cls:"廣設二戊", grp:"設計群", name:"要買午餐下去了", items:[
    {name:"豆花甜點",price:35},{name:"鬆餅",price:45},{name:"飲料",price:30},{name:"籃球九宮格遊戲",price:20}]},
  { id:"b23", num:"23", cls:"室設三戊", grp:"設計群", name:"飲JOY一下", items:[
    {name:"飲料",price:30},{name:"甜點",price:35},{name:"花枝丸",price:40}]},
  { id:"b24", num:"24", cls:"廣設三甲戊", grp:"設計群", name:"路過不空手", items:[
    {name:"文創品",price:50}]},
  { id:"b34", num:"34", cls:"影視二甲", grp:"表藝科", name:"小潘包", items:[
    {name:"麵包",price:25},{name:"餅乾",price:20}]},
  { id:"b35", num:"35", cls:"表藝二甲", grp:"表藝科", name:"藝國美食", items:[
    {name:"雲南米線",price:55}]},
  { id:"b36", num:"36", cls:"表藝二乙", grp:"表藝科", name:"乙定要吃飽", items:[
    {name:"炒泡麵",price:35},{name:"飲料",price:30},{name:"水果",price:30}]},
  { id:"b8", num:"8", cls:"音樂二甲", grp:"音樂科", name:"花雞招展", items:[
    {name:"雞塊",price:45},{name:"花雞丸",price:40}]},
  { id:"b17", num:"17", cls:"汽車一甲", grp:"汽車科", name:"一定呷ㄟ飽", items:[
    {name:"涼麵",price:45},{name:"水煎包",price:35}]},
  { id:"b18", num:"18", cls:"汽車一戊", grp:"汽車科", name:"元氣滿滿屋", items:[
    {name:"彈珠汽水",price:30}]},
  { id:"b19", num:"19", cls:"實汽一甲", grp:"汽車科", name:"乾冰汽水站", items:[
    {name:"乾冰汽水",price:30},{name:"泰式打拋豬餐