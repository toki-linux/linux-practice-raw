# docs

このフォルダには、SSHリモート操作で行った検証内容をテーマ別にまとめています。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [public_key_auth.md](public_key_auth.md) | SSH公開鍵認証の流れと設定手順 |
| [scp_file_transfer.md](scp_file_transfer.md) | scpによるファイル転送の手順 |
| [permission_error.md](permission_error.md) | `/var/www/html/` への転送時に発生した権限エラーの再現と解決 |
| [ssh_logs.md](ssh_logs.md) | SSH接続成功・失敗時のログ確認 |
| [nat_port_forwarding.md](nat_port_forwarding.md) | VirtualBox NAT環境でのポートフォワーディングの仕組み |

## 読む順番

初めて見る場合は、以下の順番で読むと流れが分かりやすいです。

1. [nat_port_forwarding.md](nat_port_forwarding.md)
2. [public_key_auth.md](public_key_auth.md)
3. [scp_file_transfer.md](scp_file_transfer.md)
4. [permission_error.md](permission_error.md)
5. [ssh_logs.md](ssh_logs.md)
