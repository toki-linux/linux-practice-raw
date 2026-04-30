## 目的
nginx -t のエラーメッセージを読んで原因を特定できるようになる


## パターン
①[セミコロン忘れ](https://github.com/toki-linux/linux-practice-raw/blob/main/nginx%E6%A7%8B%E6%96%87%E3%82%A8%E3%83%A9%E3%83%BC%E5%AE%9F%E8%B7%B5%E8%AA%B2%E9%A1%8C/%E3%82%BB%E3%83%9F%E3%82%B3%E3%83%AD%E3%83%B3%E5%BF%98%E3%82%8C)
②[波カッコミス](https://github.com/toki-linux/linux-practice-raw/blob/main/nginx%E6%A7%8B%E6%96%87%E3%82%A8%E3%83%A9%E3%83%BC%E5%AE%9F%E8%B7%B5%E8%AA%B2%E9%A1%8C/%E6%B3%A2%E3%82%AB%E3%83%83%E3%82%B3%E3%83%9F%E3%82%B9) 
③[存在し無いディレクティブ](https://github.com/toki-linux/linux-practice-raw/blob/main/nginx%E6%A7%8B%E6%96%87%E3%82%A8%E3%83%A9%E3%83%BC%E5%AE%9F%E8%B7%B5%E8%AA%B2%E9%A1%8C/%E5%AD%98%E5%9C%A8%E3%81%97%E3%81%AA%E3%81%84%E3%83%87%E3%82%A3%E3%83%AC%E3%82%AF%E3%83%86%E3%82%A3%E3%83%96)

## まとめ
① nginxは「1文字ミス」で起動しない
② nginx -t はほぼ答えを教えてくれる
③ 行番号を見るクセをつける
④ “エラー文をそのまま読む”だけで解ける
