#!/bin/bash
PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

AUTODIALER_VERSION_FULL="0.30(12.09.2019)"
AUTODIALER_VERSION=$(echo $AUTODIALER |awk 'BEGIN {FS="("} {print $1}')
user="autodialer"
pass="autodialer"
db="autodialer"
DATE=$(date +%Y%m%d%H%M)

[ "$1" = -V -o "$1" = -v ] && echo -en "Autodialer version: \033[32m$AUTODIALER_VERSION\033[0m\r\n" && exit 0;

### Functions ###
Help () {
    sed -i "s/^karagi4@yandex.ru: autodialer version.*/karagi4@yandex.ru: Welcome (wel) version: $AUTODIALER_VERSION_FULL/" $0
    grep -i "^Описание команд:" -A1000 $0 | less
}

campy () {
    campaign=$1
    retry=$2
    pause=$3
    timeout=$4
    concurrent=$5
    limit=$6
    dest=$7
    chcon=$8
    extcon=$9
    call_date=${10}
    callerid=${11}
    ad_day=${12}
    callerid_name=${13}
    d=$campaign
    s=$(date +%d-$m%y_%H:%M:%S)
    rm -f  "$campaign"
    echo "$d"

    sqlread="select concat(number,',',camp) from autodialer.$campaign where status in ('$answer_status', 'NOANS', 'BUSY', 'NOANSWER', 'CONGESTION') order by RAND() limit $limit"
    RES=`mysql -h127.0.0.1 -u $user -p$pass --skip-column-names --default-character-set=utf8 $db -e "$sqlread"`

    printf "$RES" >> $d
    echo "" >> $d

    while IFS="," read number camp name; do

    [ -n $callerid ] && Callerid="Callerid: \"$callerid_name\" <$callerid>"
    [ -z $callerid ] && Callerid="Callerid: \"$callerid_name\" <$number>"

    cat <<EOF  >  /var/spool/asterisk/tmp/$camp-$number-$ad_day

Channel: Local/$number@$chcon/n
$Callerid
MaxRetries: $retry
RetryTime: $pause
WaitTime: $timeout
Context: $extcon
Extension: $dest
Priority: 1
Setvar: campaign=$camp
Setvar: dnumber=$number
Archive: no
Account: $Account

EOF

    chown asterisk:asterisk /var/spool/asterisk/tmp/$camp-$number-$ad_day

    [ "$call_date" != "" ] && touch -mat $call_date.00 /var/spool/asterisk/tmp/$camp-$number-$ad_day
    mv /var/spool/asterisk/tmp/$camp-$number-$ad_day  /var/spool/asterisk/outgoing

    echo "$number"

    number=`expr $number + 1`

done < $d
}

### Functions End ###

case $1 in
     "")
          campaigns=$(mysql -u$user -p$pass -se "select campname from autodialer.campaign")
          campaigns=($(echo $campaigns))
          ;;
     "?"|"-?"|"help")
          Help
          ;;
     *)
          campaigns=($(echo $1))
          ;;
esac


for i in ${campaigns[@]};
do
    retry=$(mysql -u$user -p$pass -se "select retry from $db.campaign where campname='$i'")
    pause=$(mysql -u$user -p$pass -se "select pause from $db.campaign where campname='$i'")
    timeout=$(mysql -u$user -p$pass -se "select timeout from $db.campaign where campname='$i'")
    concurrent=$(mysql -u$user -p$pass -se "select concurrent from $db.campaign where campname='$i'")
    limit=$(mysql -u$user -p$pass -se "select str_limit from $db.campaign where campname='$i'")
    dest=$(mysql -u$user -p$pass -se "select exten from $db.campaign where campname='$i'")
    chcon=$(mysql -u$user -p$pass -se "select chan_context from $db.campaign where campname='$i'")
    extcon=$(mysql -u$user -p$pass -se "select ext_context from $db.campaign where campname='$i'")
    callerid=$(mysql -u$user -p$pass -se "select callerid from $db.campaign where campname='$i'")
    callerid_name=$(mysql -u$user -p$pass -se "select fullname from $db.campaign where campname='$i'")
    answer_status=$(mysql -u$user -p$pass -se "select answer_status from $db.campaign where campname='$i'")
    Account=$(mysql -u$user -p$pass -se "select account from $db.campaign where campname='$i'")
    [ "${callerid}" = "NULL" -o "${callerid}" = "" -o "${callerid}" = "0" ] && callerid="$number"
    [ "${limit}" = "NULL" -o "${limit}" = "" -o "${limit}" = "0" ] && limit="100"
    [ "${answer_status}" != "NULL" -o "${answer_status}" != "" -o "${answer_status}" != "0" ] && answer_status="ANSWER"
    if [ "$2" != "" ]; then
        ad_month=$(mysql -u$user -p$pass -se "select ad_month from $db.campaign where campname='$i'")
        ad_date=$(mysql -u$user -p$pass -se "select ad_date from $db.campaign where campname='$i'")
        ad_time=$(mysql -u$user -p$pass -se "select ad_time from $db.campaign where campname='$i'")
        ad_day=$(mysql -u$user -p$pass -se "select ad_day from $db.campaign where campname='$i'")
        [ ${#ad_month} = "1" ] && ad_month=0$ad_month
        [ "$ad_month" -gt "12" -o "$ad_month" = "" -o "$ad_month" = 00 -o "${#ad_month}" -ne 2 ] && continue
        [ ${#ad_date} = "1" ] && ad_date=0$ad_date
        [ "$ad_date" -gt 31 -o "$ad_date" = "" -o "$ad_date" = 00 -o "${#ad_date}" -ne 2 ] && continue
        [ "${ad_time:0:2}" -gt 23 -o "${ad_time:2}" -gt 59 -o "$ad_time" = "" -o "${#ad_time}" -ne 4 ] && continue
        if [ "$ad_day" -gt 0 ]; then
            call_date=$ad_month$ad_date$ad_time
            if [ "${DATE:4}" -le "$call_date" ]; then
                 campy "$i" "$retry" "$pause" "$timeout" "$concurrent" "$limit" "$dest" "$chcon" "$extcon" "$call_date" "$callerid" "$ad_day" "$callerid_name" "$Account"
            fi
            if [ "${DATE:4}" -gt "$call_date" ]; then
                call_date=$(date -I -d "${DATE:0:4}$ad_month$ad_date + $ad_day days")
                call_date=$(echo "$call_date" | sed 's#\-##g')
                call_date=$call_date$ad_time
                [ "$call_date" = "NULL" ] && continue
                ad_month=${call_date:4:2}
                ad_date=${call_date:6:2}
                ad_time=${call_date:8:4}
                mysql -u$user -p$pass -se "UPDATE $db.campaign SET ad_month='$ad_month',ad_date='$ad_date',ad_time='$ad_time' WHERE campname='$i'" > /dev/null
                campy "$i" "$retry" "$pause" "$timeout" "$concurrent" "$limit" "$dest" "$chcon" "$extcon" "$call_date" "$callerid" "$ad_day" "$callerid_name" "$Account"
            fi
### периоды времени в разработке
#            if [ "$hm" -gt 0 ]; then
#             if [ "${DATE:8}" -le "$call_date" ]; then
#                date '+%H%M' -d '+120 minutes'
#            fi
        else
            call_date=$ad_month$ad_date$ad_time
            if [ "${DATE:4}" -gt "$call_date" ]; then
                continue
            fi
            call_date=${DATE:0:4}$call_date
            [ "$call_date" = "NULL" ] && continue
            campy "$i" "$retry" "$pause" "$timeout" "$concurrent" "$limit" "$dest" "$chcon" "$extcon" "$call_date" "$callerid" "$ad_day" "$callerid_name" "$Account"
        fi
    else
        campy "$i" "$retry" "$pause" "$timeout" "$concurrent" "$limit" "$dest" "$chcon" "$extcon" "" "$callerid" "" "$callerid_name" "$Account"
    fi
done



#***********************
# Help

<< ////
Описание команд:
karagi4@yandex.ru: Welcome (wel) version: 
1) Узнать версию: ./autodialer.sh -?
2) Запустить для всех компаний: ./autodialer.sh
3) Запустить для определенной группы, например Test: ./autodialer.sh "Test"
4) Запустить создания Call файлов на определенную дату: ./autodialer.sh "" "1"

Описание:
1) Скрипт управления запуском прозвона по времени
Скрипт autodialer.sh обращается в б\д и выбирает нужные значения, проверяя их на ошибки, также задает переменные дат прозвона и создает Call файлы
Для автоматизации, скрипт нужно добавить в cron для запуска каждую минуту
crontab -e
*/1 * * * * /etc/asterisk/scripts/autodialer.sh "" "1"

Список изменений версии:
- Добавлен параметр Account для автоответа на телефонных аппаратах
- Добавлена функция запуска справки

### В планах
# Установка
# Периоды времени

////
