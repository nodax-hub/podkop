#!/bin/sh

WATCHDOG="/usr/bin/podkop-watchdog"
INIT="/etc/init.d/podkop-watchdog"

echo "======================================"
echo "Podkop Watchdog Installer"
echo "======================================"
echo ""

echo "[1/5] Installing watchdog script..."

cat << 'EOF' > $WATCHDOG
#!/bin/sh

TEST_DOMAIN="ya.ru"
TEST_IP="1.1.1.1"

CHECK_INTERVAL=20
FAIL_THRESHOLD=3

RESTART_WINDOW=600
MAX_RESTARTS=5

fail_count=0
restart_count=0
window_start=$(date +%s)

log() {
    logger -t podkop-watchdog "$1"
}

dns_ok() {
    nslookup $TEST_DOMAIN >/dev/null 2>&1
}

internet_ok() {
    ping -c1 -W2 $TEST_IP >/dev/null 2>&1
}

reset_window_if_needed() {
    now=$(date +%s)
    if [ $((now - window_start)) -gt $RESTART_WINDOW ]; then
        restart_count=0
        window_start=$now
    fi
}

restart_podkop() {

    reset_window_if_needed

    if [ "$restart_count" -ge "$MAX_RESTARTS" ]; then
        log "restart limit reached"
        return
    fi

    restart_count=$((restart_count+1))

    log "restarting podkop ($restart_count/$MAX_RESTARTS)"

    service podkop restart

    sleep 30
}

log "watchdog started"

while true
do

    if dns_ok && internet_ok
    then
        fail_count=0
        sleep $CHECK_INTERVAL
        continue
    fi

    fail_count=$((fail_count+1))
    log "check failed ($fail_count)"

    if [ "$fail_count" -ge "$FAIL_THRESHOLD" ]
    then
        restart_podkop
        fail_count=0
    fi

    sleep $CHECK_INTERVAL

done
EOF


echo "[2/5] Installing init service..."

cat << 'EOF' > $INIT
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99

start_service() {

    procd_open_instance

    procd_set_param command /usr/bin/podkop-watchdog
    procd_set_param respawn

    procd_set_param stdout 1
    procd_set_param stderr 1

    procd_close_instance
}
EOF


echo "[3/5] Setting permissions..."

chmod +x $WATCHDOG
chmod +x $INIT


echo "[4/5] Enabling service..."

/etc/init.d/podkop-watchdog enable


echo "[5/5] Starting service..."

/etc/init.d/podkop-watchdog restart

sleep 2

echo ""
echo "======================================"
echo "Installation check"
echo "======================================"

echo ""
echo "Service autostart:"

/etc/init.d/podkop-watchdog enabled && echo "OK - enabled" || echo "FAIL"


echo ""
echo "Process status:"

if pgrep -f podkop-watchdog >/dev/null; then
    echo "OK - watchdog running"
else
    echo "FAIL - watchdog not running"
fi


echo ""
echo "Service info (procd):"

ubus call service list '{"name":"podkop-watchdog"}' 2>/dev/null


echo ""
echo "Recent watchdog logs:"
echo "--------------------------------------"

logread | grep podkop-watchdog | tail -n 10

echo "--------------------------------------"

echo ""
echo "======================================"
echo "Usage"
echo "======================================"

echo ""
echo "Check logs:"
echo "  logread | grep podkop-watchdog"
echo ""

echo "Live logs:"
echo "  logread -f | grep podkop-watchdog"
echo ""

echo "Restart watchdog:"
echo "  service podkop-watchdog restart"
echo ""

echo "Stop watchdog:"
echo "  service podkop-watchdog stop"
echo ""

echo "Start watchdog:"
echo "  service podkop-watchdog start"
echo ""

echo "Disable autostart:"
echo "  service podkop-watchdog disable"
echo ""

echo "======================================"
echo "Podkop watchdog installation complete"
echo "======================================"
