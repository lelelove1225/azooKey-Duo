# azooKey Duo 開発ガイド

[azooKey](https://github.com/azooKey/azooKey)のコミット `a027203e` をベースにした非公式フォークです。

## 動作と判定

- Duo（`iPhone19,4`）では、キーボードの `windowScene.screen.bounds` の短辺を使って現在のディスプレイを判定します。確認した外側466×678pt、内側669×951ptに対し、600ptを境界としています。
- 日本語・英字ともに、外側画面ではフリック、内側画面ではQWERTYになります。日本語QWERTYはローマ字入力です。
- `UIHingeInteraction` も監視します。キーボード拡張で通知を受け取れない場合に対応するため現在のディスプレイを優先し、画面情報が未取得ならヒンジ情報を使用します。不明な状態やnil通知を「閉じた」とは解釈しません。
- 画面の短辺を使い、アプリやキーボードの幅を開閉の代用にはしません。画面寸法に依存する判定のため、将来の端末や表示設定では調整が必要になる可能性があります。
- 日本語・英字配列を実行時に上書きします。保存済みの配列設定とタブの履歴を保持し、切替処理で入力内容や変換候補を確定・消去しません。
- 数字・絵文字・明示的なカスタムタブの表示中は、そのタブを維持します。日本語・英字に戻ると現在の画面に合った配列になります。英字を表示したまま開閉した場合も、英字入力を維持して配列を切り替えます。
- 自動切替は初期状態でONです。「設定 → キーボードの入力方式 → 開閉に合わせて日本語・英字配列を切り替える」でOFFにできます。変更はキーボードを開き直したときにも読み込みます。
- Duo以外でヒンジ通知を提供しない端末では通常の設定に従います。

自動切替のためのフルアクセスは不要です。ホームジェスチャーと最下段キーの距離調整は未実装です。

DEBUGビルドには、共有コンテナへの書込みが可能な場合に `duo-layout-diagnostics.json` へ寸法・ヒンジ状態・適用配列など直近16件を保存するローカル診断処理があります。入力文字や変換候補は記録しません。

## 署名とアプリの識別

通常版と設定・辞書を分離するため、以下の識別子を使用しています。自分のチームでビルドする際は、Bundle IDとApp Groupを自分のものに置き換えてください。

| 対象 | 初期値 | 設定箇所 |
| --- | --- | --- |
| 本体 | `com.lelelove1225.azookey.duo` | MainAppターゲットのBundle Identifier、`MainApp/Info.plist`のCFBundleURLName |
| キーボード | `com.lelelove1225.azookey.duo.keyboard` | KeyboardターゲットのBundle Identifier、`SharedStore.swift`のbundleName |
| App Group | `group.com.lelelove1225.azookey.duo` | 両ターゲットのentitlements、`SharedStore.swift`のappGroupKey |
| URLスキーム | `azooKeyDuo://` | 通常版との併存用。変更は不要 |

`SharedStore.swift` は `AzooKeyCore/Sources/AzooKeyUtils/` にあります。本体とKeyboardの両ターゲットに同じDevelopment TeamとApp Groupを設定し、App Groupsに対応したプロビジョニングプロファイルを使用します。Development Teamはリポジトリでは空欄です。上流のAssociated Domainsは使用していません。

## ビルド

Xcode 27.1以降を使用します。サブモジュールを取得してください。

```sh
git submodule update --init --recursive
```

Xcodeで `azooKey.xcodeproj` を開き、`MainApp` スキームと接続した実機を選んで実行します。コマンドラインからは、リポジトリのルートで次のように実行できます。

```sh
# 自分のチームIDに置き換える
DUO_DEVELOPMENT_TEAM=YOUR_TEAM_ID
xcodebuild -project azooKey.xcodeproj -scheme MainApp \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/azookey-duo-build \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  DEVELOPMENT_TEAM="$DUO_DEVELOPMENT_TEAM" -allowProvisioningUpdates build
```

Finderメタデータによる署名エラーを避けるため、iCloud同期対象のDocumentsなどにソースを置く場合も、DerivedDataは同期対象外へ出力してください。ビルドが署名で失敗した場合、本体内に古いKeyboard拡張が残ることがあります。`BUILD SUCCEEDED` を確認した成果物をインストールしてください。

## 回帰テスト

コアパッケージのスキームを使用します。

```sh
cd AzooKeyCore
xcodebuild -scheme AzooKeyCore-Package \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath ../.build/CoreTests \
  -clonedSourcePackagesDirPath ../.build/SourcePackages \
  -only-testing:KeyboardViewsTests/AutomaticFoldLayoutTests \
  CODE_SIGNING_ALLOWED=NO test
```

2026-10-25にiOS 27.1のDuoシミュレータで16件成功しました。内外画面と回転、不明な寸法と他機種、設定OFF時の復帰、数字・絵文字・英語の維持、再初期化、数字専用欄、混在入力・未完のローマ字、重複した更新通知の抑制を検証しています。英字がフリック設定の場合のQWERTYへの切替、英字の開閉と設定OFF時の復帰、数字タブ経由・再初期化後の英字配列、明示的なカスタムタブの維持も検証しています。

アプリ側の `azooKeyTests` スキームでは、検証環境で既存依存関係のOrderedCollectionsシンボルのリンクエラーが発生しました。上記は今回の変更に対するパッケージテストの結果であり、全テストの成功を示すものではありません。

## 実機確認

iOS 27.1のiPhone Duoで、署名済みアプリのインストールと「閉じた状態から開く → フリックから日本語QWERTY」の切替を確認済みです。2026-10-25に、英字切替の修正版でも、開いた状態で日本語から英字に切り替えてQWERTYを維持することを実機で確認しました。

次の項目は実機での追加確認が必要です。

- 開いた状態から閉じると、日本語・英字ともにフリックに戻ること。
- 未確定文字の入力中の開閉と入力の継続。
- 数字・絵文字の表示を維持し、日本語へ戻ると現在の画面に合うこと。
- 縦横回転、Split View、アプリ切替、キーボード再表示、設定OFF。

単体テストは、実機へのヒンジ通知配送やOSによるキーボード拡張の再生成までを保証するものではありません。
