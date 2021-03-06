# This is half done. It's all client side for now, but there's a server 
# serving everything also. Want to api/websocket that punk but not now

parcel             := "./node_modules/parcel-bundler/bin/cli.js"
typescriptBrowser  := "./node_modules/typescript/bin/tsc --project tsconfig-browser.json"
typescriptNpm      := "./node_modules/typescript/bin/tsc --project tsconfig-npm.json"
certs              := ".certs"
HTTPS              := env_var_or_default("HTTPS", "true")
NPM_TOKEN          := env_var_or_default("NPM_TOKEN", "")
DENO_DEPS          := invocation_directory() + "/deps.ts"
# github only publishes from the "docs" directory
CLIENT_PUBLISH_DIR := invocation_directory() + "/.tmp/docs-temp"
NPM_PUBLISH_DIR    := invocation_directory() + "/dist"

@_help:
    printf "🏵 Metaframe: Tensorflow 1D conv net:    https://metapages.github.io/metaframe-predictor-conv-1d-net/\n"
    printf "\n"
    just --list

# Install required dependencies
init:
    npm i

build: (browser-assets-build "./docs") server-build npm-build

# build production brower assets
browser-assets-build out-dir="./docs" public-url="./":
    mkdir -p {{out-dir}}
    find {{out-dir}}/ -maxdepth 1 -type f -exec rm "{}" \;
    {{typescriptBrowser}} --noEmit
    ./node_modules/parcel-bundler/bin/cli.js build index.html --out-dir={{out-dir}} --public-url={{public-url}} 
    cp package.json {{out-dir}}/

server-build:
    rm -rf server.js*
    ./node_modules/typescript/bin/tsc -p tsconfig-server.json

server-start: clean build
    node server.js

# using justfile dependencies failed, the last command would not run
# publish to npm and github pages.
publish npmversionargs="patch":
    just _ensureGitPorcelain
    just _npm-clean
    just test
    just npm-version {{npmversionargs}}
    just npm-publish
    just githubpages-publish

# https://zellwk.com/blog/publish-to-npm/
npm-publish: npm-build
    #!/usr/bin/env deno run --allow-read={{NPM_PUBLISH_DIR}}/package.json --allow-run --allow-write={{NPM_PUBLISH_DIR}}/.npmrc
    import { npmPublish } from '{{DENO_DEPS}}';
    npmPublish({cwd:'{{NPM_PUBLISH_DIR}}', npmToken:'{{NPM_TOKEN}}'});

# bumps version, commits change, git tags
npm-version npmversionargs="patch":
    #!/usr/bin/env deno run --allow-run
    import { npmVersion } from '{{DENO_DEPS}}';
    await npmVersion({npmVersionArg:'{{npmversionargs}}'});

# build npm package for publishing
npm-build: _npm-clean
    @# mkdir -p {{NPM_PUBLISH_DIR}}
    @# rm -rf {{NPM_PUBLISH_DIR}}/*
    cp package.json {{NPM_PUBLISH_DIR}}/
    {{typescriptNpm}}

_npm-clean:
    mkdir -p {{NPM_PUBLISH_DIR}}
    rm -rf {{NPM_PUBLISH_DIR}}/*

_ensureGitPorcelain:
    #!/usr/bin/env deno run --allow-run
    import { ensureGitNoUncommitted } from '{{DENO_DEPS}}';
    await ensureGitNoUncommitted();

test: npm-build
    cd {{NPM_PUBLISH_DIR}} && npm link
    just test/test
    cd {{NPM_PUBLISH_DIR}} && npm unlink
    rm -rf {{NPM_PUBLISH_DIR}}/*

# update "docs" branch with the (versioned and default) current build
githubpages-publish: _ensureGitPorcelain
    just browser-assets-build ./docs/v`cat package.json | jq -r .version`
    just browser-assets-build
    git add --all docs
    git commit -m "site v`cat package.json | jq -r .version`"
    git push origin master

# # update branch:glitch to master, triggering a glitch update and rebuild
# publish-glitch: build
#     npm run clean
#     @# delete current glitch branch, no worries, it gets rebuilt every time
#     git branch -D glitch || exit 0
#     git checkout -b glitch
#     git push -u --force origin glitch
#     git checkout master

# watchexec --watch src --exts ts,html -- just browser-assets-build
# watches and builds browser client assets  (alternative to 'just run')
@client-watch:
    {{typescriptBrowser}}
    {{parcel}} watch --out-dir public index.html

# paired with client-watch (alternative to 'just run')
@watch-server:
    watchexec --restart --watch server.ts -- "npm run server-build && HTTPS={{HTTPS}} node server.js"

# starts a dev server [port 1234] (alternative to 'just client-watch' && 'just watch-server')
run: _cert-check
    {{typescriptBrowser}}
    {{parcel}} --cert {{certs}}/cert.pem \
               --key {{certs}}/cert-key.pem \
               --port 3000 \
               --host metaframe-1d-trainer.local \
               --hmr-hostname metaframe-1d-trainer.local \
               --hmr-port 3001 \
               index.html

run-no-https: _cert-check
    {{typescriptBrowser}}
    {{parcel}} --port 3000 \
               --host metaframe-1d-trainer.local \
               --hmr-hostname metaframe-1d-trainer.local \
               --hmr-port 3001 \
               index.html

# Removes generated files
clean:
    rm -rf {{certs}}
    rm -rf .tmp

# Idempotent. Ensures mkcert https certificates.
@_cert-check:
    if [ ! -f {{certs}}/cert-key.pem ]; then \
        just _mkcert; \
    fi

# DEV: generate TLS certs for HTTPS over localhost https://blog.filippo.io/mkcert-valid-https-certificates-for-localhost/
_mkcert:
    rm -rf {{certs}}
    mkdir -p {{certs}}
    cd {{certs}}/ && mkcert -cert-file cert.pem -key-file cert-key.pem metaframe-1d-trainer.local localhost
    @echo "Don't forget to add '127.0.0.1 metaframe-1d-trainer.local' to /etc/hosts"

@_require_NPM_TOKEN:
	if [ -z "{{NPM_TOKEN}}" ]; then echo "Missing NPM_TOKEN env var"; exit 1; fi