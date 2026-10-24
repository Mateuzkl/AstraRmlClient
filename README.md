# AstraRmlClient

Cliente com a SRC do Astra e suporte RmlUi 6.3, adaptado ao TFS 1.8 8.60 original.

## Executar

Use `otclient_dx_x64.exe` na raiz, junto das DLLs e pastas `data`, `modules`, `mods` e `layouts`.
O servidor local está configurado em `init.lua`: `127.0.0.1:7171:860`.
O endereço da conexão ao mundo é informado pelo servidor de login.
O perfil local chama-se `AstraRmlClient`, separado dos outros clientes.

Os arquivos grandes são armazenados com Git LFS. Ao clonar:

```powershell
git lfs install
git clone https://github.com/Mateuzkl/AstraRmlClient.git
cd AstraRmlClient
git lfs pull
```

## Compatibilidade

- HTTP usa o mapa de headers da SRC Astra e extrai o corpo das respostas `HttpResult`.
- Features e IDs Lua seguem o Astra/TFS 8.60, incluindo efeitos U16, HP/Ki U32 e offsets negativos.
- Login entende a assinatura Astra, a lista de personagens e as capabilities negociadas.
- A SRC controla a pré-caminhada; o Lua limpa as filas ao soltar teclas, cancelar ou teleportar.
- A loja antiga não envia automaticamente o opcode JSON 201 para esse TFS.
- A aba opcional `custom.otui` só é carregada quando o arquivo existe.
- Nesta SRC, os projéteis compartilham a opacidade dos efeitos; o controle independente fica desabilitado.
- Fontes LatoLatin do pacote RmlUi ficam em `data/fonts/rml`, junto da licença.

`modules/game_bot` está mantido. Os módulos antigos `cavebot_mod`, `scriptsManager-mod` e `game_maptracker` foram removidos das pastas carregadas.

## Projeto e validação

O projeto Visual Studio fica em `vc23/otclient.sln`. `vcpkg.json` e os scripts `cmake/` fornecem as dependências usadas pelos targets RmlUi/Effekseer. A compilação fica a cargo do responsável pelo projeto; o executável incluído já existia na pasta.

Para executar as verificações locais com esse executável, sem login real:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\compat\Run-Compat.ps1
```

O teste usa um perfil separado e verifica inicialização, fontes/runtime RmlUi, DAT/SPR, HTTP, pacotes de login, features, encaminhamento das teclas e ausência dos módulos removidos. A movimentação real deve ser validada em jogo.

Backups locais em `.codex-backups/`, logs, configurações pessoais e resultados de compilação não são versionados.
