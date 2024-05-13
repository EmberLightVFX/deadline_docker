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
        aws s3 cp s3://thinkbox-installers/${DEADLINE_INSTALLER_BASE}-linux-installers.tar /installers/Deadline-${DEADLINE_VERSION}-linux-installers.tar &
    fi

    if [ ! -e "/installers/Deadline-$DEADLINE_VERSION-windows-installers.zip" ]; then
        echo "Downloading Windows Installers"
        aws s3 cp s3://thinkbox-installers/${DEADLINE_INSTALLER_BASE}-windows-installers.zip /installers/Deadline-${DEADLINE_VERSION}-windows-installers.zip &
    fi

    if [ ! -e "/installers/Deadline-$DEADLINE_VERSION-osx-installers.dmg" ]; then
        echo "Downloading Mac Installers"
        aws s3 cp s3://thinkbox-installers/${DEADLINE_INSTALLER_BASE}-osx-installers.dmg /installers/Deadline-${DEADLINE_VERSION}-osx-installers.dmg &
    fi
    wait
}

cleanup_installer() {
    echo "Cleanup Installers"
    rm /build/Deadline*
    rm /build/AWSPortalLink*
    rm -rf /build/custom
}

if [ "$1" == "repository" ]; then
    if [ ! -e "./Deadline-$DEADLINE_VERSION-linux-installers.tar" ]; then
        echo "Downloading Linux Installers"
        aws s3 cp s3://thinkbox-installers/${DEADLINE_INSTALLER_BASE}-linux-installers.tar Deadline-${DEADLINE_VERSION}-linux-installers.tar
        tar -xvf Deadline-${DEADLINE_VERSION}-linux-installers.tar
    fi

    if [ ! -f /repo/settings/repository.ini ]; then

        echo "Install Repository and MongoDB"
        ./DeadlineRepository-$DEADLINE_VERSION-linux-x64-installer.run --mode unattended \
            --installmongodb true \
            --dbListeningPort ${DB_HOST} \
            --certgen_password ${DB_CERT_PASS} \
            --installSecretsManagement true \
            --secretsAdminName ${SECRETS_USERNAME} \
            --secretsAdminPassword ${SECRETS_PASSWORD}

        echo "Done Installing Repository and MongoDB"

    else
        echo "Repository Already Installed"
    fi

    echo "Launching MongoDB"
    /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin/mongod --config /opt/Thinkbox/DeadlineDatabase10/mongo/data/config.conf

elif [ "$1" == "rcs" ]; then

    echo "Deadline Remote Connection Server"
    if [ -e "$RCS_BIN" ]; then

        /bin/bash -c "$RCS_BIN"
    else
        download_additional_installers

        echo "Initializing Remote Connection Server"
        if [ -e /client_certs/Deadline10RemoteClient.pfx ]; then
            echo "Using existing certificates"
            /build/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
                --mode unattended \
                --enable-components proxyconfig \
                --repositorydir /repo \
                --dbsslcertificate /client_certs/deadline-client.pfx \
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
            /build/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
                --mode unattended \
                --enable-components proxyconfig \
                --repositorydir /repo \
                --dbsslcertificate /client_certs/deadline-client.pfx \
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

elif [ "$1" == "webservice" ] && [ "$USE_WEBSERVICE" == "TRUE" ]; then
    if [ -e "$WEB_BIN" ]; then
        /bin/bash -c "$WEB_BIN"
    else
        echo "Initializing Deadline Webservice"
        /build/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
            --mode unattended \
            --enable-components webservice_config \
            --repositorydir /repo \
            --dbsslcertificate /client_certs/deadline-client.pfx \
            --dbsslpassword ${DB_CERT_PASS} \
            --noguimode true \
            --slavestartup false \
            --webservice_enabletls false

        cleanup_installer

        "$WEB_BIN"
    fi

elif [ "$1" == "worker" ]; then
    echo "not yet implemented"

elif [ "$1" == "forwarder" ] && [ "$USE_LICENSE_FORWARDER" == "TRUE" ]; then
    if [ -e "$FORWARDER_BIN" ]; then
        /bin/bash -c "$FORWARDER_BIN"
    else
        echo "Initializing License Forwarder"
        /build/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
            --mode unattended \
            --repositorydir /repo \
            --dbsslcertificate /client_certs/deadline-client.pfx \
            --dbsslpassword ${DB_CERT_PASS} \
            --noguimode true \
            --slavestartup false \
            --secretsAdminName ${SECRETS_USERNAME} \
            --secretsAdminPassword ${SECRETS_PASSWORD}

        cleanup_installer

        "$FORWARDER_BIN" -sslpath /client_certs
    fi

elif [ "$1" == "zt-forwarder" ] && [ "$USE_LICENSE_FORWARDER" == "TRUE" ]; then
    if [ -e "$FORWARDER_BIN" ]; then
        /usr/sbin/zerotier-one -d
        /bin/bash -c "$FORWARDER_BIN"
    else
        echo "Initializing ZT License Forwarder"
        /build/DeadlineClient-$DEADLINE_VERSION-linux-x64-installer.run \
            --mode unattended \
            --repositorydir /repo \
            --dbsslcertificate /client_certs/deadline-client.pfx \
            --dbsslpassword ${DB_CERT_PASS} \
            --noguimode true \
            --slavestartup false \
            --secretsAdminName ${SECRETS_USERNAME} \
            --secretsAdminPassword ${SECRETS_PASSWORD}

        cleanup_installer

        curl -s https://install.zerotier.com | /bin/bash
        echo 9994 >/var/lib/zerotier-one/zerotier-one.port
        chmod 0600 /var/lib/zerotier-one/zerotier-one.port
        /usr/sbin/zerotier-one -d
        sleep 5
        /usr/sbin/zerotier-cli status
        /usr/sbin/zerotier-cli join ${ZT_NETWORK_ID}

        "$FORWARDER_BIN" -sslpath /client_certs
    fi
else
    /bin/bash
fi
