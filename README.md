# azooKey Duo

[iPhone向け日本語キーボード azooKey](https://github.com/azooKey/azooKey)をベースに、iPhone Duoの開閉に合わせた配列の自動切替を追加した非公式フォークです。

- **閉じたらフリック、開いたら日本語QWERTY（ローマ字入力）**に自動切替。
- 数字・絵文字・英語のタブを維持し、日本語に戻ると現在の画面に合った配列を表示。
- 保存済みの配列設定は保持。自動切替は設定からOFFにできます。
- 通常版と並べてインストールできる別アプリ「azooKey Duo」です。

自動切替のためのフルアクセスは不要です。現在はソースコードの公開のみで、このフォークのApp Store／TestFlight版はありません。

## ビルドと導入

Xcode 27.1以降と、実機ではApp Groupsを利用できる署名環境が必要です。

```sh
git clone --recursive https://github.com/lelelove1225/azooKey-Duo.git
cd azooKey-Duo
open azooKey.xcodeproj
```

自分のDevelopment Team・Bundle ID・App Groupを設定し、`MainApp`スキームで実機にインストールしてください。設定箇所・テスト方法は[開発ガイド](docs/duo-development.md)を参照してください。

インストール後、iOSの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で **azooKey Duo** を追加し、入力欄の地球儀から選びます。

## 確認状況

2026-10-25時点で、iPhone Duo実機の「閉じた状態から開く → フリックからQWERTY」を確認済み。配列判定・タブ維持・入力状態などの回帰テスト12件が成功しています。閉じる方向の切替・回転・Split Viewなどの実機確認は継続中です。

ホームジェスチャーと最下段キーの距離調整は未実装です。このフォーク固有の不具合は[このリポジトリのIssues](https://github.com/lelelove1225/azooKey-Duo/issues)へお願いします。

## ライセンス・謝辞

原作者・貢献者によるazooKeyの実装を利用しています。MIT Licenseと著作権表示を維持しています。詳しくは[LICENSE](LICENSE)を参照してください。

---

以下は上流azooKeyのREADMEです。App Store・TestFlight・コミュニティの案内は通常版を指します。

# azooKey

azooKeyはiOS / iPadOS向けの日本語キーボードアプリです。Swiftで実装され、「ニューラルかな漢字変換システム Zenzai」を含む独自開発の高精度変換エンジン、ライブ変換、さらにカスタムキー・カスタムタブなどのユニークなカスタマイズ機能を提供します。

azooKeyは[App Store](https://apps.apple.com/jp/app/azookey-%E8%87%AA%E7%94%B1%E8%87%AA%E5%9C%A8%E3%81%AA%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89%E3%82%A2%E3%83%97%E3%83%AA/id1542709230)で公開しています。

azooKeyの変換エンジンについては[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を参照ください。

azooKeyのmacOS版については[azooKey-Desktop](https://github.com/azooKey/azooKey-Desktop)を参照ください。

## コミュニティ＆ベータ版

azooKeyの開発に参加したい方、使い方に質問がある方、要望や不具合報告がある方は、ぜひ[azooKeyのDiscordサーバ](https://discord.gg/dY9gHuyZN5)にご参加ください。

開発中のベータ版は[TestFlight](https://testflight.apple.com/join/x6TKEeB2)で利用できます。フィードバックをDiscordやIssue等でお寄せください。

## 開発ガイド
パフォーマンス改善、バグ修正、機能追加などのPull Requestを歓迎します。機能追加の場合は事前にIssueで議論した方がスムーズです。

開発は基本的に`main`で行います。新規にPRを作成する場合、まずこのレポジトリをフォークし、`main`からブランチを切ってください。

[Let's Contribute](docs/CONTRIBUTING.md)も合わせてお読みください。

### ビルド・利用方法

Apple Developer Account（無料）が必要です。開発環境は最新のXcodeを利用してください。

1. azooKeyを開発環境にクローンします。azooKeyはサブモジュールを利用しているため、`--recursive`オプションを必ず追加してください。

   ```
   git clone https://github.com/azooKey/azooKey --recursive
   ```

1. `azooKey.xcodeproj`を開き、Xcodeの指示に従って「Run (Command+R)」を実行してください。

1. アプリを開くとキーボードのインストール方法が説明されるので、従ってください。

### テスト方法
[Document](docs/tests.md)をご覧ください。

### 辞書の変更

標準辞書は[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)の`KanaKanjiConverterModuleWithDefaultDictionary`に同梱されています。利用する辞書を変更する場合は、同リポジトリ側の辞書参照を変更してください。

### さらに詳しく

`docs/`内の[Document](./docs/overview.md)をご覧ください。

不明な点は気軽にIssue等でご質問ください。

## 今後のリリース
* 現在、v3.0.1に向けた作業を行っています。

## azooKeyを支援する
GitHub Sponsorsをご利用ください。

## ライセンス
Copyright (c) 2020-2025 Keita Miwa (ensan).

azooKeyはMIT Licenseでライセンスされています。詳しくは[LICENSE](./LICENSE)をご覧ください。
