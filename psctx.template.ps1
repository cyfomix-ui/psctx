# Legacy PSCtx config template.
# PSCtx 0.8.1 or later writes .psctx.json by default to avoid
# ExecutionPolicy / unsigned-script issues.
@{
    Name = 'MyProject'
    EnableAmpersandFork = $true
    ShowProjectNameInPrompt = $false
    Env = @{}
}
