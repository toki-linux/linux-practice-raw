
# docs

このフォルダには、linux-monitoring-lab で行った検証内容や、監視スクリプト作成時に学んだことをまとめています。

監視スクリプトの動作確認、自動復旧の検証、発生したトラブル、サービス状態・ポート状態・HTTP応答の違いなどを整理しています。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [auto_recovery_test.md](auto_recovery_test.md) | `myapp.service` 停止時に監視スクリプトで自動復旧できるかを検証した記録 |
| [monitoring_notes.md](monitoring_notes.md) | 監視スクリプト作成時に学んだことのメモ |
| [permission_denied_tmp.md](permission_denied_tmp.md) | `/tmp` 配下へログ出力しようとした際のPermission deniedについて整理した記録 |
| [service_port_http_check_notes.md](service_port_http_check_notes.md) | サービス状態・ポート状態・HTTP応答を分けて確認する理由を整理したメモ |

---

## 読む順番

初めて見る場合は、以下の順番で読むと流れが分かりやすいです。

1. [service_port_http_check_notes.md](service_port_http_check_notes.md)
2. [auto_recovery_test.md](auto_recovery_test.md)
3. [permission_denied_tmp.md](permission_denied_tmp.md)
4. [monitoring_notes.md](monitoring_notes.md)

---

## 各ファイルの位置づけ

### service_port_http_check_notes.md

サービス状態・ポート状態・HTTP応答を分けて確認する理由をまとめたファイルです。

`systemctl` でサービスがactiveでも、期待したポートでLISTENしているとは限らず、HTTP応答が正常とは限らないことを整理しています。

---

### auto_recovery_test.md

`myapp.service` を意図的に停止させ、監視スクリプトで異常検知と自動復旧ができるかを検証した記録です。

rootのcronからスクリプトを実行し、停止していたサービスを自動起動できることを確認しています。

---

### permission_denied_tmp.md

監視スクリプトのログ出力先として `/tmp/web_stack_check.log` を使用した際に、Permission denied が発生した問題を整理した記録です。

実行ユーザー、ファイルの所有者、権限、ログ出力先の見直しについてまとめています。

---

### monitoring_notes.md

監視スクリプト作成時に学んだことをまとめたメモです。

`systemctl is-active --quiet`、`grep -q`、自動復旧直後のタイミング差、`sleep` を入れた理由などを整理しています。

---

## このフォルダの位置づけ

このフォルダは、監視スクリプトそのものではなく、検証内容や学びを整理するためのドキュメント置き場です。

スクリプトの動作結果だけでなく、なぜその確認が必要なのか、どのように原因を切り分けたのかを残すことを目的にしています。
