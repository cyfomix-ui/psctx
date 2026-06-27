@{
    Name = 'MyProject'

    # このプロジェクト配下だけ、行末 & をバックグラウンド実行として扱います。
    # 例: notepad .\.psctx.ps1 &
    EnableAmpersandFork = $true

    # $true にすると、プロンプトの白い $ の後ろに [ProjectName] を出します。
    ShowProjectNameInPrompt = $false

    # このプロジェクト配下にいる間だけ適用する環境変数です。
    Env = @{
        # 'DOTNET_NOLOGO' = '1'
        # 'DOTNET_CLI_TELEMETRY_OPTOUT' = '1'
    }
}
