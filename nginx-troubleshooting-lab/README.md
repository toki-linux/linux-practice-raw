## 障害パターン一覧

### 502 Bad Gateway

- [01 502 - upstreamサービス停止](incidents/01_502_upstream_stopped.md)
- [02 502 - proxy_passのポート不一致](incidents/02_502_wrong_proxy_pass_port.md)
- [03 502 - systemd ExecStartミス](incidents/03_502_systemd_execstart_error.md)
- [04 502 - systemd WorkingDirectoryミス](incidents/04_502_systemd_workingdirectory_error.md)
- [05 502 - bind先IPミス](incidents/05_502_bind_address_mismatch.md)
- [06 502 - 不要なproxyヘッダー設定](incidents/06_502_unnecessary_proxy_header.md)

### 404 Not Found

- [07 404 - index.html不足](incidents/07_404_missing_index.md)

### 403 Forbidden

- [08 403 - directory index is forbidden](incidents/08_403_directory_index_forbidden.md)
- [09 403 - ファイル権限不足](incidents/09_403_file_permission_denied.md)
