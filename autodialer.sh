#!/bin/bash
PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

AUTODIALER_VERSION_FULL="1.3.1(17.02.2020)"
AUTODIALER_VERSION=$(echo $AUTODIALER_VERSION_FULL |awk 'BEGIN {FS="("} {print $1}')
DATE=$(date +%Y%m%d%H%M)
Path=$(dirname $0)
[ "$1" = "-v" -o "$1" = "-V" ] && echo -en "Autodialer version: \033[32m$AUTODIALER_VERSION_FULL\033[0m\r\n" && exit 0;
[ -z `find $Path/autodialer.conf -type f -name "autodialer.conf" 2> /dev/null` ] && echo "Файла конфигурации autodialer.conf не существует!
Создайте файл конфигурации рядом со скриптом $0 и внесите в него параметры подключение к б\д в формате:
db_user='user'
db_pass='pass'
db='db_autodialer'" && exit 0;
source $Path/autodialer.conf


### Functions ###
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

    sqlread="select concat(number,',',camp) from autodialer.$campaign where status in ('$answer_status', 'NOANS', 'BUSY', 'NOANSWER', 'CONGESTION', 'CANCEL', 'CHANUNAVAIL') order by RAND() limit $limit"
    RES=`mysql -h127.0.0.1 -u $db_user -p$db_pass --skip-column-names --default-character-set=utf8 $db -e "$sqlread" |sed 's/ ,/,/g'`

    printf "$RES" >> $d
    echo "" >> $d

    while IFS="," read number camp name; do

    [ -n $callerid ] && Callerid="Callerid: \"$callerid_name\" <$callerid>"
    [ -z $callerid ] && Callerid="Callerid: \"$callerid_name\" <$number>"

    cat <<EOF  >  $adtmp/$camp-$number-$ad_day

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

    chown asterisk:asterisk $adtmp/$camp-$number-$ad_day

    [ "$call_date" != "" ] && touch -mat $call_date.00 $adtmp/$camp-$number-$ad_day
# В версии < 1.2.0
#    mv $adtmp/$camp-$number-$ad_day  /var/spool/asterisk/outgoing

    echo "$number"

    number=`expr $number + 1`

done < $d
}

### Functions End ###

case $1 in
     "")
          echo -e "Autodialer version: \033[32m$AUTODIALER_VERSION\033[0m\r\nСинтаксис:\n$0 -a => Обычный запуск, прозвон по всем кампаниям\n$0 -t => Запуск создания Call файлов на определенное время\дату для всех кампаний
$0 CampTest => Запуск прозвона для компании CampTest\n$0 CampTest -t Запуск создания Call файлов на определенное время\дату для компании CampTest" && exit
          ;;
     "-a")
          adtmp=$(mktemp -d /var/spool/asterisk/tmp/.autodialer-XXX)
          echo $adtmp
          campaigns=$(mysql -u$db_user -p$db_pass -se "select campname from autodialer.campaign")
          campaigns=($(echo $campaigns))
          ;;
     "-t")
          adtmp=$(mktemp -d /var/spool/asterisk/tmp/.autodialer-XXX)
          Tdate="-t"
          campaigns=$(mysql -u$db_user -p$db_pass -se "select campname from autodialer.campaign")
          campaigns=($(echo $campaigns))
          ;;
     *)
          adtmp=$(mktemp -d /var/spool/asterisk/tmp/.autodialer-XXX)
          campaigns=($(echo $1))
          ;;
esac


if [ "$2" = "-t" ]; then
    Tdate="-t"
else
    Tdate=""
fi

for i in ${campaigns[@]};
do
    Check=$(mysql -uautodialer -pautodialer -se "select campname from $db.campaign where campname='$i'")
    [ -z $Check ] && echo "Название кампании $i указано не верно!" && rm -rf $adtmp && exit 0;
    retry=$(mysql -u$db_user -p$db_pass -se "select retry from $db.campaign where campname='$i'")
    pause=$(mysql -u$db_user -p$db_pass -se "select pause from $db.campaign where campname='$i'")
    timeout=$(mysql -u$db_user -p$db_pass -se "select timeout from $db.campaign where campname='$i'")
    concurrent=$(mysql -u$db_user -p$db_pass -se "select concurrent from $db.campaign where campname='$i'")
    limit=$(mysql -u$db_user -p$db_pass -se "select str_limit from $db.campaign where campname='$i'")
    dest=$(mysql -u$db_user -p$db_pass -se "select exten from $db.campaign where campname='$i'")
    chcon=$(mysql -u$db_user -p$db_pass -se "select chan_context from $db.campaign where campname='$i'")
    extcon=$(mysql -u$db_user -p$db_pass -se "select ext_context from $db.campaign where campname='$i'")
    callerid=$(mysql -u$db_user -p$db_pass -se "select callerid from $db.campaign where campname='$i'")
    callerid_name=$(mysql -u$db_user -p$db_pass -se "select fullname from $db.campaign where campname='$i'")
    answer_status=$(mysql -u$db_user -p$db_pass -se "select answer_status from $db.campaign where campname='$i'")
    Account=$(mysql -u$db_user -p$db_pass -se "select account from $db.campaign where campname='$i'")
    [ "${callerid}" = "NULL" -o "${callerid}" = "" -o "${callerid}" = "0" ] && callerid="$number"
    [ "${limit}" = "NULL" -o "${limit}" = "" -o "${limit}" = "0" ] && limit="100"
    case "${answer_status}" in
     "NULL"|""|"0")
          answer_status="ANSWER"
          ;;
     *)
          answer_status="NOANS"
          ;;
     esac

    if [ "$Tdate" = "-t" ]; then
        ad_month=$(mysql -u$db_user -p$db_pass -se "select ad_month from $db.campaign where campname='$i'")
        ad_date=$(mysql -u$db_user -p$db_pass -se "select ad_date from $db.campaign where campname='$i'")
        ad_time=$(mysql -u$db_user -p$db_pass -se "select ad_time from $db.campaign where campname='$i'")
        ad_day=$(mysql -u$db_user -p$db_pass -se "select ad_day from $db.campaign where campname='$i'")
        [ ${#ad_month} = "1" ] && ad_month=0$ad_month
        [ "$ad_month" -gt "12" -o "$ad_month" = "" -o "$ad_month" = 00 -o "${#ad_month}" -ne 2 ] && continue
        [ ${#ad_date} = "1" ] && ad_date=0$ad_date
        [ "$ad_date" -gt 31 -o "$ad_date" = "" -o "$ad_date" = 00 -o "${#ad_date}" -ne 2 ] && continue
        [ "${ad_time:0:2}" -gt 23 -o "${ad_time:2}" -gt 59 -o "$ad_time" = "" -o "${#ad_time}" -ne 4 ] && continue
        if [ -n "$ad_day" ] && [ $ad_day -gt 0 ]; then
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
                mysql -u$db_user -p$db_pass -se "UPDATE $db.campaign SET ad_month='$ad_month',ad_date='$ad_date',ad_time='$ad_time' WHERE campname='$i'" > /dev/null
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

# Автонабор
if [ -d $adtmp ]; then
mv $adtmp/*  /var/spool/asterisk/outgoing
rm -rf $adtmp
fi

# Изменения в $AUTODIALER_VERSION_FULL
# добавлен статус CHANUNAVAIL в запрос sqlread
