# nginx-troubleshooting-lab

## 概要

Nginxで発生する代表的なエラーを再現し、ログ・サービス状態・ポート状態・設定ファイルを確認しながら原因を切り分けた学習ポートフォリオです。

主に以下のエラーを扱っています。

- `502 Bad Gateway`
- `404 Not Found`
- `403 Forbidden`

単にエラーを直すだけでなく、以下の流れで原因を整理しています。

```text
症状を確認する
  ↓
ログを見る
  ↓
サービス状態を確認する
  ↓
ポート状態を確認する
  ↓
設定ファイルを確認する
  ↓
原因を切り分ける
  ↓
解決する
```

---

## 目的

このリポジトリでは、Nginx・systemd・Python簡易HTTPサーバを使い、Webサービス障害時の基本的な切り分けを実践することを目的としています。

特に、以下を重視しています。

- `access.log` と `error.log` から原因を読み取る
- Nginx側の問題か、upstream側の問題かを分ける
- systemdサービスの起動失敗をログから確認する
- `ss` や `curl` を使ってポート状態・HTTP応答を確認する
- 502 / 404 / 403 の違いを整理する

---

## 検証環境

| 項目 | 内容 |
|---|---|
| OS | Ubuntu Server |
| Webサーバ | Nginx |
| upstream | Python `http.server` |
| サービス管理 | systemd |
| 確認コマンド | `curl`, `ss`, `systemctl`, `journalctl`, `tail`, `grep` |
| 主なログ | `/var/log/nginx/access.log`, `/var/log/nginx/error.log` |

---

## 構成イメージ

```text
Client / curl
    ↓
Nginx :80
    ↓ /app/ をリバースプロキシ
Python App :3000
    ↓
systemd myapp.service
```

---

## 障害パターン一覧

| No | ステータス | 原因 | 主な確認ポイント |
|---|---|---|---|
| 01 | 502 | Pythonアプリサービス停止 | `systemctl status myapp`, `ss`, `error.log` |
| 02 | 502 | `proxy_pass` ポート不一致 | `proxy_pass`, `error.log` の upstream |
| 03 | 502 | `ExecStart` ミス | `status=203/EXEC`, `journalctl -u myapp` |
| 04 | 502 | `WorkingDirectory` ミス | `status=200/CHDIR`, `journalctl -u myapp` |
| 05 | 502 | bind先IPミス | `ss` の IP:PORT, `proxy_pass` |
| 06 | 502 | 不要なproxyヘッダー設定 | `upstream prematurely closed connection` |
| 07 | 404 | Python側の `index.html` 不足 | Python単体アクセス |
| 08 | 404 | `alias` パス結合ミス | `error.log` の探索パス |
| 09 | 404 | `root` 設定ミス | `root` と実ファイル配置 |
| 10 | 403 | ファイル権限不足 | `permission denied`, `ls -l` |
| 11 | 403 | `deny all;` | `access forbidden by rule` |
| 12 | 403 | `directory index is forbidden` | indexなし + autoindex無効 |
| 13 | 403 | `index` 指定ミス | `index` ディレクティブ |

---

## 詳細ドキュメント

### 502 Bad Gateway

- [01 502 - upstreamサービス停止](incidents/01_502_upstream_stopped.md)
- [02 502 - proxy_passのポート不一致](incidents/02_502_wrong_proxy_pass_port.md)
- [03 502 - systemd ExecStartミス](incidents/03_502_systemd_execstart_error.md)
- [04 502 - systemd WorkingDirectoryミス](incidents/04_502_systemd_workingdirectory_error.md)
- [05 502 - bind先IPミス](incidents/05_502_bind_address_mismatch.md)
- [06 502 - 不要なproxyヘッダー設定](incidents/06_502_unnecessary_proxy_header.md)

### 404 Not Found

- [07 404 - Python側の index.html 不足](incidents/07_404_missing_index.md)
- [08 404 - aliasパス結合ミス](incidents/08_404_alias_path_mismatch.md)
- [09 404 - root設定ミス](incidents/09_404_root_path_mismatch.md)

### 403 Forbidden

- [10 403 - ファイル権限不足](incidents/10_403_file_permission_denied.md)
- [11 403 - deny allによるアクセス拒否](incidents/11_403_deny_all.md)
- [12 403 - directory index is forbidden](incidents/12_403_directory_index_forbidden.md)
- [13 403 - index指定ミス](incidents/13_403_index_directive_mismatch.md)

---

## ディレクトリ構成

```text
nginx-troubleshooting-lab/
├── README.md
└── incidents/
    ├── 01_502_upstream_stopped.md
    ├── 02_502_wrong_proxy_pass_port.md
    ├── 03_502_systemd_execstart_error.md
    ├── 04_502_systemd_workingdirectory_error.md
    ├── 05_502_bind_address_mismatch.md
    ├── 06_502_unnecessary_proxy_header.md
    ├── 07_404_missing_index.md
    ├── 08_404_alias_path_mismatch.md
    ├── 09_404_root_path_mismatch.md
    ├── 10_403_file_permission_denied.md
    ├── 11_403_deny_all.md
    ├── 12_403_directory_index_forbidden.md
    └── 13_403_index_directive_mismatch.md
```

---

## 502 / 404 / 403 の違い

```text
502 Bad Gateway
→ Nginxはリクエストを受け取ったが、upstreamへ正常に接続・中継できない

404 Not Found
→ Nginxまたはupstreamが、指定されたファイルやパスを見つけられない

403 Forbidden
→ ファイルやディレクトリには到達できているが、権限や設定により表示できない
```

---

## 切り分けで意識したこと

障害発生時は、以下の順番で確認しました。

```text
1. curlで症状を確認する
2. access.logでリクエストが届いているか確認する
3. error.logで具体的な原因を確認する
4. systemctlでサービス状態を確認する
5. ssでポートの待ち受けを確認する
6. curlでupstream単体にアクセスする
7. Nginx設定ファイルを確認する
8. systemd serviceファイルを確認する
```

---

## 学び

Nginxのエラーは、表示されるステータスコードだけでは原因を特定できない。

同じ `502 Bad Gateway` でも、Pythonアプリ停止・`proxy_pass` ミス・systemd設定ミス・bind先IPミスなど、原因は複数ある。

また、`404 Not Found` や `403 Forbidden` も、Nginxが直接返している場合と、upstreamであるPythonアプリが返している場合がある。

そのため、ログ・サービス状態・ポート状態・設定ファイルを順番に確認し、どの層で問題が起きているかを切り分けることが重要だと学んだ。
