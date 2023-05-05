#!/bin/bash
## 01-basic.sh
source ./config.sh
########## Basic config for controller
## Internet Check
if ping -c 1 google.com >> /dev/null 2>&1; then
    echo "It's Online."
else
    echo "It's Offline. Sorry."
    exit 1
fi
## 컨트롤러 호스트 이름 바꾸기
echo ${HOST_pass[0]} | sudo -S hostnamectl set-hostname ${HOST_name[0]}

# 컴퓨터 서버 수에 따라 호스트네임 추가
# echo의 stdout을 뒷문장의 stdin으로 넘겨준다 -> sudo -S의 stdin, root유저에 호스트 비밀번호를 사용하여 변경한다
# inplace 옵션 덮어쓰기, 'a는 파일에 append 한다는 이야기. host ip 문자열, 공백 1칸, host 이름 해서 /etc/hosts파일 안에다 저장.
for ((i = 0; i <= $COMPUTENODE; i++))
do
    echo ${HOST_pass[0]} | sudo -S sed -i '$ a '${HOST_ip[$i]}' '${HOST_name[$i]} /etc/hosts
done

ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

PKGS='expect'
if [ $QUIETAPT -eq 1 ]; then echo ${HOST_pass[0]} | sudo -S apt install -q -y $PKGS
else echo ${HOST_pass[0]} | sudo -S apt install -y $PKGS; fi

for ((i = 0; i <= $COMPUTENODE; i++))
do
/usr/bin/expect <<EOE
set prompt "#"
spawn bash -c "ssh-copy-id ${HOST_name[$i]}"
expect {
"yes/no" { send "yes\r"; exp_continue}
-nocase "password" {send "${HOST_pass[$i]}\r"; exp_continue }
$prompt
}
EOE
done
for ((i = 1; i <= $COMPUTENODE; i++))
do
ssh ${HOST_user[$i]}@${HOST_name[$i]} "echo ${HOST_pass[$i]} | sudo -S hostnamectl set-hostname ${HOST_name[$i]}"
done

if [ $INSTALL_HEAT -eq 1 ]; then shfile=($(ls | grep -e "[0-9][0-9][-].*[.]sh" | grep -v "00-pre.sh" | sed 's/:.*//'))
else shfile=($(ls | grep -e "[0-9][0-9][-].*[.]sh" | grep -v "00-pre.sh" | grep -v "heat" | sed 's/:.*//'))
fi
if [ $INIT_OPENSTACK -eq 0 ]; then unset "shfile[${#shfile[@]}-1]"; fi

# copy config file for script
for ((i = 0; i <= $COMPUTENODE; i++))
do
    scp ./config.sh ${HOST_name[$i]}:
done

# run scripts
echo ${shfile[*]}
for i in "${shfile[@]}"
do
ssh ${HOST_name[0]} 'bash -s' < $i
done

mkdir backup

