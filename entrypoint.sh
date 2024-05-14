#!/bin/bash

RCS_BIN=/opt/Thinkbox/Deadline10/bin/deadlinercs
WEB_BIN=/opt/Thinkbox/Deadline10/bin/deadlinewebservice
WORKER_BIN=/opt/Thinkbox/Deadline10/bin/deadlineworker
FORWARDER_BIN=/opt/Thinkbox/Deadline10/bin/deadlinelicenseforwarder
DEADLINE_CMD=/opt/Thinkbox/Deadline10/bin/deadlinecommand

configure_from_env() {
    if [[ -z "$DEADLINE_REGION" ]]; then
        ${DEADLINE_CMD} SetIniFileSetting Region ${DEADLINE_REGION}
    fi
}

download_additional_installers() {
    echo "Downloading Installers"
    mkdir -p /installers

    if [ ! -e "/installers/Deadline-$DEADLINE_VERSION-linux-installers.tar" ]; then
        echo "Downloading Linux Installers"
        # s3://thinkbox-installers/Deadline/10.3.2.1/Linux/Deadline-10.3.2.1-linux-installers.tar
        # aws s3api get-object --bucket thinkbox-installers --key Deadline/10.3.2.1/Linux/Deadline-10.3.2.1-linux-installers.tar Deadline-10.3.2.1-linux-installers.tar
        aws s3api get-object --bucket thinkbox-installers --key "Deadline/${DEADLINE_VERSION}/Linux/Deadline-${DEADLINE_VERSION}-linux-installers.tar" /installers/Deadline-${DEADLINE_VERSION}-linux-installers.tar
    fi

    if [ ! -e "/installers/Deadline-$DEADLINE_VERSION-windows-installers.zip" ]; then
        echo "Downloading Windows Installers"
        # s3://thinkbox-installers/Deadline/10.3.2.1/Windows/Deadline-10.3.2.1-windows-installers.zip
        # aws s3api get-object --bucket thinkbox-installers --key Deadline/10.3.2.1/Windows/Deadline-10.3.2.1-windows-installers.zip Deadline-10.3.2.1-windows-installers.zip
        aws s3api get-object --bucket thinkbox-installers --key "Deadline/${DEADLINE_VERSION}/Windows/Deadline-${DEADLINE_VERSION}-windows-installers.zip" /installers/Deadline-${DEADLINE_VERSION}-windows-installers.zip
    fi

    if [ ! -e "/installers/Deadline-$DEADLINE_VERSION-osx-installers.dmg" ]; then
        echo "Downloading Mac Installers"
        # s3://thinkbox-installers/Deadline/10.3.2.1/Mac/Deadline-10.3.2.1-osx-installers.dmg
        # aws s3api get-object --bucket thinkbox-installers --key Deadline/10.3.2.1/Mac/Deadline-10.3.2.1-osx-installers.dmg Deadline-10.3.2.1-osx-installers.dmg
        aws s3api get-object --bucket thinkbox-installers --key "Deadline/${DEADLINE_VERSION}/Mac/Deadline-${DEADLINE_VERSION}-osx-installers.dmg" /installers/Deadline-${DEADLINE_VERSION}-osx-installers.dmg
    fi
    wait
}

unpack_installer() {
    if [ ! -e "/unpacked_installers/DeadlineRepository-$DEADLINE_VERSION-linux-x64-installer.run" ]; then
        echo "Downloading Linux Installers"
        tar -xvf /installers/Deadline-${DEADLINE_VERSION}-linux-installers.tar -C /unpacked_installers
    fi
}

cleanup_installer() {
    echo "Cleanup Installers"
    rm /build/Deadline*
    rm /build/AWSPortalLink*
    rm -rf /build/custom
}

if [ "$1" == "repository" ]; then
    echo "Deadline Repostitory"
    download_additional_installers
    unpack_installer

    if [ ! -f /repo/settings/repository.ini ]; then

        echo "Install Repository and MongoDB"
        /unpacked_installers/DeadlineRepository-$DEADLINE_VERSION-linux-x64-installer.run \
            --mode unattended \
            --installmongodb true \
            --dbListeningPort 27100 \
            --certgen_password ${DB_CERT_PASS} \
            --installSecretsManagement false \
            --secretsAdminName ${SECRETS_USERNAME} \
            --secretsAdminPassword ${SECRETS_PASSWORD} \
            --prefix /repo \
            --dbOverwrite false \
            --dbLicenseAcceptance accept \
            --debuglevel 4 \
            --dbhost ${DB_HOST}

        echo "Done Installing Repository and MongoDB"

    else
        echo "Repository Already Installed"
    fi
    echo "Stopping running mongodb"
    /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod --shutdown --dbpath /opt/Thinkbox/DeadlineDatabase10/mongo/data

    echo "Copying over mongodb config"
    cp /opt/data/config.conf /opt/Thinkbox/DeadlineDatabase10/mongo/data/config.conf

    echo "Copying certificate"
    cp /opt/Thinkbox/DeadlineDatabase10/certs/Deadline10Client.pfx /client_certs/Deadline10Client.pfx

    echo "Re-launching MongoDB"
    /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod --config /opt/data/config.conf --tlsCertificateKeyFilePassword ${DB_CERT_PASS}

elif [ "$1" == "rcs" ]; then
    echo "Deadline Remote Connection Server"
    if [ -e "$RCS_BIN" ]; then

        /bin/bash -c "$RCS_BIN"
    else
        download_additional_installers
        unpack_installer

        echo "Initializing Remote Connection Server"
        if [ -e /client_certs/Deadline10RemoteClient.pfx ]; then
            echo "Using existing certificates"
            /unpacked_installers/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
                --mode unattended \
                --enable-components proxyconfig \
                --repositorydir /repo \
                --dbsslcertificate /client_certs/Deadline10Client.pfx \
                --dbsslpassword ${DB_CERT_PASS} \
                --noguimode true \
                --slavestartup false \
                --httpport ${RCS_HTTP_PORT} \
                --tlsport ${RCS_TLS_PORT} \
                --enabletls true \
                --tlscertificates existing \
                --servercert /server_certs/${HOSTNAME}.pfx \
                --cacert /server_certs/ca.crt \
                --secretsAdminName ${SECRETS_USERNAME} \
                --secretsAdminPassword ${SECRETS_PASSWORD} \
                --osUsername root

        else
            echo "Generating Certificates"
            /unpacked_installers/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
                --mode unattended \
                --enable-components proxyconfig \
                --repositorydir /repo \
                --dbsslcertificate /client_certs/Deadline10Client.pfx \
                --dbsslpassword ${DB_CERT_PASS} \
                --noguimode true \
                --slavestartup false \
                --httpport ${RCS_HTTP_PORT} \
                --tlsport ${RCS_TLS_PORT} \
                --enabletls true \
                --tlscertificates generate \
                --generatedcertdir ~/certs \
                --clientcert_pass ${RCS_CERT_PASS} \
                --secretsAdminName ${SECRETS_USERNAME} \
                --secretsAdminPassword ${SECRETS_PASSWORD} \
                --osUsername root

            cp /root/certs/Deadline10RemoteClient.pfx /client_certs/Deadline10RemoteClient.pfx
            cp /root/certs/${HOSTNAME}.pfx /server_certs/${HOSTNAME}.pfx
            cp /root/certs/ca.crt /server_certs/ca.crt
        fi

        cleanup_installer

        "$DEADLINE_CMD" secrets ConfigureServerMachine ${SECRETS_USERNAME} defaultKey root --password ${SECRETS_PASSWORD}

        "$RCS_BIN"
    fi
else
    /bin/bash
fi
