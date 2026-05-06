# NAT環境とポートフォワーディング

## 目的

VirtualBoxのNAT環境で、ホストPCからUbuntu VMへSSH接続するために、ポートフォワーディングを使う理由と仕組みを整理する。

この検証では、ホスト側の2222番ポートをUbuntu VM側の22番ポートへ転送し、接続元MacからUbuntu ServerへSSH接続できることを確認する。

---

## 環境

| 項目 | 内容 |
|---|---|
| 接続元 | Mac |
| 接続先 | Ubuntu Server |
| 仮想化環境 | VirtualBox |
| ネットワーク | NAT |
| ホスト側ポート | 2222 |
| ゲスト側ポート | 22 |
| 接続コマンド | `ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost` |

---

## 前提

VirtualBoxのネットワークをNATにしている場合、Ubuntu VMはホストPCの内側にあるような状態になる。

Ubuntu VMから外部へ通信することはできるが、ホスト側や外部ネットワークからUbuntu VMへ直接アクセスしにくい。

そのため、ホスト側のポートをUbuntu VM側のポートへ転送する設定が必要になる。

```text
Mac
  ↓
VirtualBox NAT
  ↓
Ubuntu VM
```
今回の検証では、VirtualBoxのポートフォワーディングを使って、Mac側の2222番ポートをUbuntu VM側の22番ポートへ転送した。

ポートフォワーディングの構成

今回の設定では、以下のようにポートを転送する。
```txt
Mac localhost:2222
  ↓
VirtualBox ポートフォワーディング
  ↓
Ubuntu VM :22
  ↓
sshd
```
対応関係は以下。
```txt
項目	内容
ホストIP	127.0.0.1 または localhost
ホストポート	2222
ゲストIP	Ubuntu VM
ゲストポート	22
プロトコル	TCP
接続コマンド
```
NAT環境でポートフォワーディングを使っているため、接続元Macからは以下のように接続する。
```bash
ssh -p 2222 -i ~/.ssh/my_test_key toki@localhost
```
このコマンドの意味。
```txt
ssh
→ SSH接続する

-p 2222
→ 接続元Macから見た接続先ポートを2222番にする

-i ~/.ssh/my_test_key
→ 公開鍵認証で使う秘密鍵を指定する

toki@localhost
→ localhost上の2222番ポートへ、tokiユーザーとして接続する
```
ここでの localhost は、接続元Mac自身を指す。

ただし、VirtualBoxのポートフォワーディングによって、Macの2222番ポートへの通信がUbuntu VMの22番ポートへ転送される。

なぜ localhost なのか

localhost は通常、自分自身を表す。

今回の接続元はMacなので、localhost はMac自身を指す。
```bash
ssh -p 2222 toki@localhost
```
これは一見すると、Mac自身にSSH接続しているように見える。

しかし、VirtualBoxで以下のようなポートフォワーディングを設定している。
```txt
Mac localhost:2222
  ↓
Ubuntu VM :22
```
そのため、Macの2222番ポートへ送った通信は、VirtualBoxによってUbuntu VMの22番ポートへ転送される。

つまり、実際の流れは以下。
```txt
Macで ssh -p 2222 toki@localhost を実行
  ↓
Macの2222番ポートへ接続
  ↓
VirtualBoxが受け取る
  ↓
Ubuntu VMの22番ポートへ転送
  ↓
Ubuntu VMのsshdが応答
```
## なぜ -p 2222 なのか

SSHの通常ポートは22番。

しかし、今回Macから直接Ubuntu VMの22番ポートへ接続しているわけではない。

接続元Macから見えている入口は、ホスト側の2222番ポート。

そのため、SSHコマンドでは以下のように指定する。
```bash
ssh -p 2222 toki@localhost
```
もし -p 2222 を指定しない場合、SSHはデフォルトの22番ポートへ接続しようとする。
```bash
ssh toki@localhost
```
この場合、Mac自身の22番ポートへ接続しようとするため、Ubuntu VMには届かない。

nc でポートフォワーディングを確認した結果

Mac側で以下のコマンドを実行し、ホスト側の2222番ポートへ接続できるか確認した。
```bash
nc -vz localhost 2222
```
## 実行結果
```txt
nc: connectx to localhost port 2222 (tcp) failed: Connection refused
Connection to localhost port 2222 [tcp/rockwell-csp2] succeeded!
```
最初に Connection refused が表示されたが、その後 Connection succeeded が表示された。

これは、localhost のIPv6側では接続に失敗し、IPv4側では接続に成功したものだと考えられる。

この結果から、Mac側の localhost:2222 へ接続できることを確認した。

Ubuntu側のSSHログ

nc でポート確認を行った後、Ubuntu側でSSHログを確認した。
```bash
sudo journalctl -u ssh
```
確認できたログ。
```txt
May 06 13:54:31 ubuntu-toki sshd[14710]: error: kex_exchange_identification: Connection closed by remote host
May 06 13:54:31 ubuntu-toki sshd[14710]: Connection closed by 10.0.2.2 port 49721
```
これは、nc による接続確認がUbuntu側の sshd まで届いたものの、nc はSSHログインを行うコマンドではないため、SSH認証の前に接続が閉じられたことを示している。

つまり、秘密鍵認証に失敗したログではない。

nc はポートに接続できるかを確認するコマンドであり、SSHログインまでは行わない。

そのため、Ubuntu側の sshd から見ると、接続は来たがSSHのやりとりを続けずに閉じられたように見える。

## 確認できた通信経路

今回の nc と journalctl の結果から、以下の通信経路が成立していることを確認できた。
```txt
Mac localhost:2222
  ↓
VirtualBox ポートフォワーディング
  ↓
Ubuntu VM :22
  ↓
sshd
```
つまり、Mac側の2222番ポートに送った通信が、VirtualBoxによってUbuntu VM側の22番ポートへ転送されている。

## SSH接続できない時の切り分け

SSH接続できない場合は、以下の順番で確認すると原因を分けやすい。
```txt
1. Ubuntu VM側で ssh サービスが起動しているか
2. Ubuntu VM側で 22番ポートが LISTEN しているか
3. VirtualBoxのポートフォワーディング設定が正しいか
4. Mac側から localhost:2222 に接続できるか
5. SSHコマンドで -p 2222 を指定しているか
6. ユーザー名が正しいか
7. 秘密鍵の指定が正しいか
8. サーバ側ログに接続記録が残っているか
```
確認コマンド例。
```txt
sudo systemctl status ssh
ss -tulnp | grep ':22'
nc -vz localhost 2222
ssh -vvv -p 2222 -i ~/.ssh/my_test_key toki@localhost
sudo journalctl -u ssh -n 30
```
## 確認できたこと
NAT環境では、Ubuntu VMに直接SSH接続しにくい場合がある
VirtualBoxのポートフォワーディングを使うことで、ホスト側ポートからVM側ポートへ通信を転送できる
localhost:2222 への接続が、Ubuntu VMの22番ポートへ転送される
SSHコマンドでは、ホスト側ポートである2222番を指定する必要がある
localhost は接続元Mac自身を指すが、ポートフォワーディングによってUbuntu VMへ通信が渡される
nc でポート到達確認をすると、Ubuntu側の sshd に接続ログが残ることがある
kex_exchange_identification のログは、今回の場合、秘密鍵認証の失敗ではなく、nc がSSH認証前に接続を閉じたことを示している

## 学び

NAT環境では、Ubuntu VMはホストPCの内側にあるため、外部やホスト側から直接VMの22番ポートへSSH接続しにくい場合がある。

そのため、VirtualBoxのポートフォワーディングを使って、ホスト側の2222番ポートをUbuntu VM側の22番ポートへ転送する。
```txt
Mac localhost:2222
  ↓
VirtualBox
  ↓
Ubuntu VM :22
```
この設定により、接続元Macでは ssh -p 2222 toki@localhost を実行することで、Ubuntu VMのSSHサービスへ接続できる。

今回の検証を通じて、SSH接続では以下を分けて考えることが重要だと分かった。
```txt
接続元から見た宛先
  ↓
VirtualBoxの転送設定
  ↓
Ubuntu VM側の待ち受けポート
  ↓
SSH認証
```
nc は「ポートまで届くか」を確認するためのコマンドであり、SSHログインまでは行わない。

そのため、nc で接続できることは、通信経路やポートフォワーディングが機能していることの確認になる。

一方で、実際にSSHログインできるかどうかは、ユーザー名・秘密鍵・authorized_keys・.ssh の権限など、認証側の設定も確認する必要がある。

つまり、ssh -p 2222 toki@localhost はMac自身へログインしているのではなく、Macの2222番ポートに入った通信がVirtualBoxによってUbuntu VMの22番ポートへ転送されている。
