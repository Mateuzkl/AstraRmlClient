# AstraRmlClient no navegador

Esta pasta contém a base web da `main` do AstraClient, commit `689e37f6f51c651e4f42ad58eab42e7d9bd11266`. A lista de assets foi adaptada ao AstraRmlClient; arquivos novos só entram no pacote depois de incluídos explicitamente em `production-assets.json`.

## Compilar

Ative o Emscripten **6.0.8** e disponibilize CMake, Ninja, Node.js e Python no terminal. A partir da raiz:

```powershell
powershell -ExecutionPolicy Bypass -File .\browser\build-wasm.ps1 -BuildType Release
```

O script gera os arquivos em `build-wasm-release/dist`. Para selecionar outro DAT/SPR, passe `-ThingsDirectory` com a pasta do pack. A compilação deve ser executada pelo responsável pelo projeto.

## Conectar ao TFS

O TFS usa TCP, portanto o navegador precisa de dois bridges WebSocket: um para o login e outro para a porta do jogo. Configure `config.js` com os endereços usados pelo cliente e informados pelo servidor. Nesta instalação:

```javascript
window.ASTRA_CONFIG = {
  websocketOverrides: {
    '127.0.0.1:7171': '/login',
    '192.168.31.183:7172': '/game'
  }
};
```

Os caminhos precisam apontar para os bridges da sua implantação. `nginx.conf.example` e os documentos em `docs/astra-web-security-*` explicam HTTPS, cabeçalhos e encaminhamento. A configuração de domínio, certificados e publicação pertence à implantação.

## Validar sem compilar

```powershell
node --test browser/tests/*.test.cjs
python tools/check_browser_assets.py
python browser/tests/text_assets.py
python browser/tests/manifest.py
```

Os testes JavaScript e Python verificam o carregador, cache, rotas, persistência e assets. Eles não substituem uma compilação WebAssembly nem o teste da conexão aos bridges. O teste de nginx é opcional e depende do ambiente de implantação.
