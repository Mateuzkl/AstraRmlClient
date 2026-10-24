# AstraRmlClient

Cliente com a SRC do Astra e suporte RmlUi 6.3, adaptado ao TFS 1.8 8.60 original.

A base nativa (`src/`, `cmake/` e os arquivos versionados de `vc23/`) foi sincronizada com a `main` do AstraClient no commit `689e37f6f51c651e4f42ad58eab42e7d9bd11266`. Os arquivos experimentais de Effekseer foram retirados dessa base. O executável incluído é o anterior à sincronização; recompile para gerar o binário correspondente à SRC atual.

Os caches locais de RmlUi que ainda apontavam para a pasta do AstraClient original foram guardados em `.codex-backups/`. O próximo build configura o RmlUi nesta pasta; use **Rebuild Solution** para gerar um executável completo da nova base.

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
- A loja usa o protocolo binário Astra: `0xFD` para respostas e catálogo, histórico, compras e transferências nos opcodes próprios do TFS.
- Estatísticas só são enviadas se `Services.stats` tiver um endpoint configurado; não há envio fixo para o domínio do OTCv8.
- A aba opcional `custom.otui` só é carregada quando o arquivo existe.
- Nesta SRC, os projéteis compartilham a opacidade dos efeitos; o controle independente fica desabilitado.
- Fontes LatoLatin do pacote RmlUi ficam em `data/fonts/rml`, junto da licença.

`modules/game_bot` está mantido. Os módulos antigos `cavebot_mod`, `scriptsManager-mod` e `game_maptracker` foram removidos das pastas carregadas.

## Prey do Astra

`modules/game_prey` contém a janela completa do AstraClient: seleção entre nove criaturas, busca por criatura, bônus, duração, custos, desbloqueio permanente e Prey Tracker. Abra pelos botões **Prey Dialog** e **Prey Tracker** durante o jogo.

O módulo usa as mensagens nativas do TFS original (`0xE8`/`0xE9` para estado/preços, além dos recursos e atualizações de duração). As imagens, fontes e estilos próprios estão dentro do módulo para preservar o visual das outras janelas. A integração com a loja usa o adaptador Astra já instalado neste cliente.

## Projeto e validação

O projeto Visual Studio fica em `vc23/otclient.sln`. `vcpkg.json` e os scripts `cmake/` fornecem as dependências do RmlUi. A compilação fica a cargo do responsável pelo projeto; o executável incluído já existia na pasta.

Para executar as verificações locais com esse executável, sem login real:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\compat\Run-Compat.ps1
powershell -ExecutionPolicy Bypass -File .\tests\compat\Run-Compat.ps1 -Suite toolbar
powershell -ExecutionPolicy Bypass -File .\tests\compat\Run-Compat.ps1 -Suite rml
```

O teste declara o nome do perfil antes da inicialização nativa e verifica inicialização, fontes/runtime RmlUi, DAT/SPR, HTTP, pacotes de login, features, encaminhamento das teclas, loja, estados/controles do Prey e ausência dos módulos removidos. A movimentação real e as operações do Prey devem ser validadas em jogo.

Backups locais em `.codex-backups/`, logs, configurações pessoais e resultados de compilação não são versionados.

## Botões e telas RmlUi

Os botões em jogo usam uma grade de 24 × 24 pixels, altura automática e os ícones do Astra. Imagens estáticas mantêm o mesmo quadro ao ativar; sprites com dois quadros usam as áreas corretas de Off/On.

As telas RmlUi da base original estão em `modules/client_rml*` e `modules/game_rml*`. As opções RmlUi usam o `client_options` deste cliente; a árvore de skills continua uma demonstração local, sem integração de atributos com o servidor.

## Versão web

O código web original está em `browser/`, acompanhado das ferramentas `tools/browser_*` e da integração no `CMakeLists.txt`. A lista explícita `browser/production-assets.json` corresponde aos assets deste cliente, incluindo Prey, bot, RmlUi e o layout retro.

Use [browser/README.md](browser/README.md) para preparar a compilação e os bridges. A versão web não foi compilada nem publicada durante essa sincronização.
