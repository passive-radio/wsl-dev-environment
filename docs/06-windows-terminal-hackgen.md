# 06. Windows Terminal + HackGen フォント

[HackGen](https://github.com/yuru7/HackGen) は Hack (欧文) + GenJyuuGothic (和文) の
合成フォント。Nerd Font パッチ済みの "Console" バリアントを使う(端末での記号幅を
標準化するため、HackGen自身のドキュメントが端末用途として言及している variant)。

## インストール(Windows側、管理者権限不要)

WSLから叩く場合:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./windows-terminal/install-hackgen-font.ps1)"
```

Windows側のPowerShellから直接叩く場合はそのまま:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File install-hackgen-font.ps1
```

これは Explorer の右クリック「インストール」と同じ `Shell.Application` の
COMインターフェースを使っていて、管理者権限が無ければ自動的に**現在のユーザーだけ**
(`%LOCALAPPDATA%\Microsoft\Windows\Fonts`、レジストリは
`HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts`) にインストールされる。

登録される正確なファミリー名は **"HackGen Console NF"**(スペース込み)。

確認:

```powershell
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" |
    Select-Object -Property "*HackGen*"
```

## Windows Terminal のデフォルトフォントに設定する

### 方法A: スクリプトで自動適用(バックアップ付き)

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./windows-terminal/apply-default-font.ps1)"
```

`settings.json` (Store版・非Store版どちらも自動検出) をタイムスタンプ付きでバックアップ
してから、最初に見つかった `"face": "..."` だけを置換する。プロファイル別に別フォントを
指定している場合はそれらは変わらない(意図的 - どのプロファイルを触るべきか推測しないため)。

### 方法B: 手動

`windows-terminal/settings.snippet.json` の内容を、Windows Terminal の設定画面
(`Ctrl+,` → JSONファイルを開く) の `profiles.defaults` にマージする:

```jsonc
"profiles": {
    "defaults": {
        "font": { "face": "HackGen Console NF" }
    }
}
```

保存すると Windows Terminal はホットリロードするので、開いているウィンドウにも
再起動なしで反映される。

## 参考: settings.json の場所

- Microsoft Store版: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
  (パッケージのハッシュ部分 `8wekyb3d8bbwe` は環境によらず同じ値になることが多いが、
  `apply-default-font.ps1` は `Microsoft.WindowsTerminal*` でワイルドカード検索するので
  ハードコードの必要はない)
- 非Store版: `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`
