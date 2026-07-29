# ============================================================
# Atualizar Painel - Obra 421 LRV Tripoloni
# ============================================================
# O que este script faz, toda vez que roda:
#   1. Pega o .xlsx mais recente na pasta de origem dos ensaios (a
#      planilha sincronizada do SharePoint via OneDrive)
#   2. Copia o relatorio de escavadeiras/CBM (arquivo fixo, outra pasta)
#   3. Copia os dois para dentro da pasta do painel
#   4. Envia (git add + commit + push) para o GitHub
#
# Depois disso, o site publicado (GitHub Pages) atualiza sozinho
# em cerca de 1 minuto.
# ============================================================

$ErrorActionPreference = "Continue"

# --- AJUSTE ESTES CAMINHOS SE PRECISAR -------------------------
$sourceFolder = "C:\Users\lucianaboas\OneDrive - Construtora Tripoloni\Arquivos de Antonio Leonardo Pereira Guimaraes - Anexos (RESUMO DE ENSAIOS - OBRA 421 LRV TRIPOLONI.REV02)"
$sourceEscavadeira = "C:\Users\lucianaboas\OneDrive - Construtora Tripoloni\Planejamento\08 - Controles\02 - Terraplenagem\RELATÓRIO ESCAVADEIRA e CBM.xlsx"
$destFolder   = "C:\Users\lucianaboas\OneDrive - Construtora Tripoloni\Documentos\Execução da obra"
# ---------------------------------------------------------------

$destFile = Join-Path $destFolder "dados.xlsx"
$destFileEscavadeira = Join-Path $destFolder "dados_escavadeira.xlsx"
$logFile  = Join-Path $destFolder "atualizacao_log.txt"

function Log($msg) {
    $linha = "[{0}] {1}" -f (Get-Date -Format "dd/MM/yyyy HH:mm:ss"), $msg
    Write-Output $linha
    Add-Content -Path $logFile -Value $linha
}

Log "----- Iniciando atualizacao -----"

if (-not (Test-Path $sourceFolder)) {
    Log "ERRO: pasta de origem (ensaios) nao encontrada: $sourceFolder"
    exit 1
}

$source = Get-ChildItem -Path $sourceFolder -Filter "*.xlsx" -File |
          Where-Object { $_.Name -notlike "~`$*" } |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if (-not $source) {
    Log "ERRO: nenhum arquivo .xlsx encontrado em $sourceFolder"
    exit 1
}

Log ("Arquivo de ensaios encontrado: " + $source.Name + " (modificado em " + $source.LastWriteTime + ")")

try {
    Copy-Item -Path $source.FullName -Destination $destFile -Force
    Log ("Copiado para: " + $destFile)
} catch {
    Log ("ERRO ao copiar arquivo de ensaios: " + $_.Exception.Message)
    exit 1
}

if (Test-Path $sourceEscavadeira) {
    try {
        Copy-Item -Path $sourceEscavadeira -Destination $destFileEscavadeira -Force
        Log ("Copiado relatorio de escavadeiras para: " + $destFileEscavadeira)
    } catch {
        Log ("AVISO: nao consegui copiar o relatorio de escavadeiras: " + $_.Exception.Message)
    }
} else {
    Log ("AVISO: relatorio de escavadeiras nao encontrado em: " + $sourceEscavadeira)
}

Set-Location $destFolder

# Garante que o git enxerga essa pasta como o repositorio correto
git rev-parse --is-inside-work-tree *>$null
if ($LASTEXITCODE -ne 0) {
    Log "ERRO: essa pasta nao parece ser um repositorio Git. Rode 'git init' e configure o remoto primeiro."
    exit 1
}

git add "dados.xlsx" "dados_escavadeira.xlsx" *>$null

$statusPendente = git status --porcelain
if (-not $statusPendente) {
    Log "Nenhuma mudanca nos dados desde a ultima atualizacao - nada para enviar."
    Log "----- Fim -----"
    exit 0
}

$mensagem = "Atualizacao automatica de dados - " + (Get-Date -Format "dd/MM/yyyy HH:mm")
git commit -m "$mensagem" 2>&1 | ForEach-Object { Log $_ }

$pushResult = git push 2>&1
$pushResult | ForEach-Object { Log $_ }

if ($LASTEXITCODE -eq 0) {
    Log ("Push feito com sucesso: " + $mensagem)
} else {
    Log "ERRO no push. Verifique se o 'git push' manual funciona sem pedir senha nesta pasta."
}

Log "----- Fim -----"
