## 目的

`scp` を使って、接続元PCからUbuntuサーバへファイルを転送できることを確認する。

この検証では、公開鍵認証でSSH接続できる状態を前提に、接続元PCで作成したファイルをUbuntuサーバのホームディレクトリへ転送する。

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

---

## 手順

### 1. 接続元PCで転送用ファイルを作成する

```bash
echo "scp test" > scp_test.txt
```
作成されたことを確認する。
```bash
ls -l scp_test.txt
cat scp_test.txt
```
2. `scp`でUbuntuサーバへ転送する
```bash
scp -P 2222 -i ~/.ssh/my_test_key scp_test.txt toki@localhost:~
```
ここでは、NAT環境のポートフォワーディングを使っているため、`-P 2222` を指定している。

また、公開鍵認証で接続するため、`-i ~/.ssh/my_test_key` で使用する秘密鍵を指定している。

3. UbuntuサーバへSSH接続する
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
5. 転送されたファイルを確認する
```bash
ls -l ~/scp_test.txt
cat ~/scp_test.txt
```

想定結果。
```txt
scp test
```
確認できたこと
`scp` で接続元PCからUbuntuサーバへファイルを転送できた
NAT環境では `scp `でも` -P 2222 `のようにポート指定が必要になる
`scp` でもSSH接続と同じ秘密鍵を使って認証する
転送先は接続ユーザー toki の権限で書き込まれる
学び

``scp はファイル転送コマンドだが、内部ではSSH接続を使っている。

そのため、SSH接続と同じように、接続先ポート、接続ユーザー、秘密鍵の指定が必要になる。

sshの場合
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
scpの場合
```bash
scp -P 2222 -i ~/.ssh/my_test_key scp_test.txt toki@localhost:~
```
`ssh` ではポート指定に小文字の -p を使うが、`scp `では大文字の -P を使う。

また、転送先に指定した ~ は、接続先ユーザーである toki のホームディレクトリを意味する。

今回の検証では、`scp_test.txt` を `/home/toki/ `に転送できることを確認した。
