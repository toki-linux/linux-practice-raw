# scp転送時の権限エラー

## 目的

`scp` を使って、接続元PCからUbuntuサーバへファイルを転送する際に、転送先ディレクトリの権限によって失敗するケースを再現する。

この検証では、一般ユーザー `toki` で `/var/www/html/` へ直接ファイルを転送しようとして失敗することを確認し、その後、正しい手順でファイルを配置する方法を確認する。

---

## 環境

| 項目 | 内容 |
|---|---|
| 接続元 | Mac |
| 接続先 | Ubuntu Server |
| 仮想化環境 | VirtualBox |
| ネットワーク | NAT / ポートフォワーディング |
| 接続先ポート | ホスト側: 2222 → VM側: 22 |
| 認証方式 | 公開鍵認証 |
| 転送先 | `/var/www/html/` |

---

## 前提

`scp` はSSH接続を使ってファイルを転送する。

そのため、転送先にファイルを書き込む権限は、接続したユーザーの権限に依存する。

今回の場合、`toki` ユーザーで接続しているため、`/var/www/html/` に直接書き込む権限がない場合、転送は失敗する。

---

## 手順

### 1. 接続元PCで転送用ファイルを作成する

接続元PCで、検証用のHTMLファイルを作成する。

```bash
echo "permission test" > test.html
```
作成されたことを確認する。
```bash
ls -l test.html
cat test.html
```
2. /var/www/html/ へ直接転送して失敗を確認する

接続元PCから、/var/www/html/ へ直接転送する。
```bash
scp -P 2222 -i ~/.ssh/my_test_key test.html toki@localhost:/var/www/html/
```
想定される結果。
``` bash
scp: dest open "/var/www/html/test.html": Permission denied
scp: failed to upload file test.html to /var/www/html/
```
このエラーから、toki ユーザーには /var/www/html/ にファイルを書き込む権限がないことが分かる。

3. 一度ホームディレクトリへ転送する

権限が必要な場所へ直接転送できないため、一度 toki ユーザーのホームディレクトリへ転送する。
```bash
scp -P 2222 -i ~/.ssh/my_test_key test.html toki@localhost:~
```
4. UbuntuサーバへSSH接続する
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
6. ホームディレクトリに転送されたことを確認する
```bash
ls -l ~/test.html
cat ~/test.html
```
8. sudoを使って /var/www/html/ へ移動する

/var/www/html/ は一般ユーザーでは書き込めないため、サーバ側で sudo を使ってファイルを移動する。
```bash
sudo mv ~/test.html /var/www/html/
```
配置できたことを確認する。
```bash
ls -l /var/www/html/test.html
```
7. ブラウザまたはcurlで表示確認する

Nginxが起動している状態で、HTTP応答を確認する。
```bash
curl http://localhost/
```
想定結果。
```txt
permission test
```
結果

scp で /var/www/html/ へ直接ファイルを転送しようとしたところ、Permission denied で失敗した。

一方で、/home/toki/ へ転送した後、サーバ側で sudo mv を実行することで、/var/www/html/ にファイルを配置できた。

確認できたこと
scp は接続ユーザーの権限で転送先へ書き込む
一般ユーザー toki では /var/www/html/ に直接書き込めない場合がある
scp に sudo を直接つけても、転送先サーバ側でsudoされるわけではない
権限が必要な場所へ配置する場合は、一度ホームディレクトリへ転送してから、サーバ側で sudo mv する流れが使える
学び

scp はファイル転送コマンドだが、転送先にファイルを書き込む時は、接続先ユーザーの権限で処理される。

今回の場合、toki ユーザーでSSH接続しているため、/var/www/html/ に直接ファイルを書き込む権限がなく、Permission denied になった。
```txt
接続元PC
  ↓ scp
接続先Ubuntu
  ↓ tokiユーザーの権限で書き込み
/var/www/html/
```
権限が必要な場所へファイルを配置したい場合は、以下のように分けて考えるとよい。
```txt
1. scpで /home/toki/ に転送する
2. SSHでサーバへ入る
3. sudo mv で /var/www/html/ へ移動する
```
この流れにすることで、ファイル転送は一般ユーザー権限で行い、権限が必要な配置作業だけをサーバ側で sudo によって実行できる。

注意点

scp の前に sudo を付けても、接続先サーバ側でroot権限として書き込めるわけではない。
```bash
sudo scp index.html toki@localhost:/var/www/html/
```
この場合の sudo は、接続元PC側で scp コマンドをroot権限で実行しているだけであり、接続先Ubuntu側の /var/www/html/ へroot権限で書き込むという意味ではない。

接続先の権限が必要な場所へ配置する場合は、サーバ側で sudo mv や sudo cp を使う。
