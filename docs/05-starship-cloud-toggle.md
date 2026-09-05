# 05. プロンプトのクラウド識別情報 表示/非表示切り替え

## 何が問題だったか

starshipの設定ファイルが無い(組み込みデフォルトのまま)状態だと、`gcloud`/`aws`の
モジュールが**アクティブな設定を検出すると常に**プロンプトへ出る。具体的には毎回の
プロンプトに GCPアカウントのメールアドレスやAWSのリージョン/プロファイルが
表示され続ける。画面録画や配信をするときに映り込むと困る。

```
~ on ☁️  (ap-northeast-1) on ☁️  you@example.com
❯
```

## 対処

`STARSHIP_CONFIG` 環境変数で読み込む設定ファイルを丸ごと切り替えられることを利用する。

- `starship/starship.toml` (デフォルト、`~/.config/starship.toml` に配置): `gcloud`/`aws`
  モジュールを `disabled = true` にする。他のモジュール(ディレクトリ、git、character等)は
  一切触っていないので、starship組み込みのデフォルト動作のまま。
- `starship/starship-cloud.toml` (`~/.config/starship-cloud.toml` に配置): 同じモジュールを
  `disabled = false` にしただけの、開発用バリアント。

`shell/interactive.sh` に切り替え用の関数を定義:

```bash
cloud-prompt-on()  { export STARSHIP_CONFIG="$HOME/.config/starship-cloud.toml"; }
cloud-prompt-off() { unset STARSHIP_CONFIG; }
```

starshipはプロンプト描画のたびに新しいプロセスとして起動し `STARSHIP_CONFIG` を
読み直すので、**シェルを再起動せずに次のプロンプトから即座に反映される**。

## 使い方

- 何もしなければ常に非表示(新しいシェルはデフォルト設定から始まる)
- gcloud/AWS作業中に見たい時: `cloud-prompt-on`
- 元に戻す: `cloud-prompt-off`、または新しいシェルを開く

**重要**: これは表示の切り替えだけで、`gcloud auth`/AWS認証情報そのものには一切
触れない。ログイン状態は常に維持される。

## 他のクラウド/モジュールにも応用できる

同じ仕組みで、他に隠したいstarshipモジュール(`aws`以外にも`azure`, `kubernetes`,
`docker_context`等)があれば、同様に両方のtomlファイルへ `disabled` の行を足すだけでよい。
