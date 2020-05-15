# This is half done. It's all client side for now, but there's a server 
# serving everything also. Want to api/websocket that punk but not now

parcel           := "./node_modules/parcel-bundler/bin/cli.js"
typescriptCheck  := "./node_modules/typescript/bin/tsc --build tsconfig-browser.json"
certs            := ".certs"

@_help:
    printf "🏵 Metaframe: Tensorflow 1D conv net\n"
    printf "\n"
    just --list

# Install required dependencies
init:
    npm i

# Idempotent. 
@cert-check:
    if [ ! -f {{certs}}/cert-key.pem ]; then \
        just _mkcert; \
    fi

# build production brower assets
build-client:
    {{typescriptCheck}}
    {{parcel}} build index.html

publish:
    @# delete current glitch branch, no worries, it gets rebuilt every time
    git branch -D glitch || exit 0
    git checkout -b glitch
    git push -u --force origin glitch
    git checkout master

# watchexec --watch src --exts ts,html -- just build-client
# watches and builds browser client assets  (alternative to 'just run')
@watch-client:
    {{parcel}} watch --out-dir public index.html

# paired with watch-client (alternative to 'just run')
@watch-server:
    watchexec --restart --watch server.ts -- "npm run build-server && HTTPS=true node server.js"

# starts a dev server [port 1234] (alternative to 'just watch-client' && 'just watch-server')
run: cert-check
    {{typescriptCheck}}
    {{parcel}} --cert {{certs}}/cert.pem \
               --key {{certs}}/cert-key.pem \
               --port 3000 \
               --host metaframe-1d-trainer.local \
               --hmr-hostname metaframe-1d-trainer.local \
               --hmr-port 3001 \
               index.html

# Removes generated files
clean:
    rm -rf {{certs}}
    rm -rf node_modules

# DEV: generate TLS certs for HTTPS over localhost https://blog.filippo.io/mkcert-valid-https-certificates-for-localhost/
_mkcert:
    rm -rf {{certs}}
    mkdir -p {{certs}}
    cd {{certs}}/ && mkcert -cert-file cert.pem -key-file cert-key.pem metaframe-1d-trainer.local localhost
    @echo "Don't forget to add '127.0.0.1 metaframe-1d-trainer.local' to /etc/hosts"
