#!/bin/bash

if [ ! -e "~/keys/mongodb.pem" ]; then
    echo "Generating db cert"
    python ./SSLGeneration/ssl_gen.py --ca --cert-org ${CERT_ORG} --cert-ou ${CERT_OU} --keys-dir ~/keys
    python ./SSLGeneration/ssl_gen.py --server --cert-name ${DB_HOST} --alt-name minisforum --alt-name ${ROOT_DOMAIN} --alt-name localhost --alt-name 127.0.0.1 --keys-dir ~/keys
    python ./SSLGeneration/ssl_gen.py --client --cert-name deadline-client --keys-dir ~/keys
    python ./SSLGeneration/ssl_gen.py --pfx --cert-name deadline-client --keys-dir ~/keys --passphrase ${DB_CERT_PASS}
    cat ~/keys/${DB_HOST}.crt ~/keys/${DB_HOST}.key >~/keys/mongodb.pem
    cat ~/keys/ca.crt ~/keys/ca.key >~/keys/ca.pem
    echo "Done generating db cert"
    echo "Copying generated db cert"
    cp ~/keys/deadline-client.pfx /client_certs/deadline-client.pfx
    echo "5"
fi

echo "Run MongoDB"
#/opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod --config /opt/Thinkbox/DeadlineDatabase10/mongo/data/config.conf
tail -f /dev/null
echo "6"
