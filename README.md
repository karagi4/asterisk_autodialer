# autodialer v"1.3.2(17.02.2020)" README:
Bash Asterisk autodialer script

Создадим б\д
```
create database autodialer;
grant all privileges on autodialer.* to autodialer@localhost identified by 'autodialer';
flush privileges;
```

Создание таблицы групп
```
CREATE TABLE IF NOT EXISTS `campaign` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campname` varchar(64) DEFAULT NULL,
  `chan_context` varchar(16) DEFAULT NULL,
  `retry` varchar(16) DEFAULT NULL,
  `pause` varchar(4) DEFAULT NULL,
  `timeout` varchar(16) DEFAULT NULL,
  `ext_context` varchar(16) DEFAULT NULL,
  `exten` varchar(8) DEFAULT NULL,
  `concurrent` varchar(8) DEFAULT NULL,
  `ad_month` varchar(4) DEFAULT NULL,
  `ad_date` varchar(4) DEFAULT NULL,
  `ad_time` varchar(4) DEFAULT NULL,
  `ad_day` varchar(4) DEFAULT NULL,
  `time_end` varchar(4) DEFAULT NULL,
  `callerid` varchar(16) DEFAULT NULL,
  `fullname` varchar(40) DEFAULT NULL,
  `timestamp` varchar(16) DEFAULT NULL,
  `answer_status` varchar(16) DEFAULT NULL,
  `account` varchar(16) DEFAULT NULL,
  `str_limit` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `camp` (`campname`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
```

Вставка параметров для группы Test в таблицу campaign
```
INSERT INTO `autodialer`.`campaign` (`id`, `campname`, `chan_context`, `retry`, `pause`, `timeout`, `ext_context`, `exten`, `concurrent`, `ad_month`, `ad_date`, `ad_time`, `ad_day`, `callerid`, `fullname`, `answer_status`) VALUES ('', 'Test', 'outcalling', '2', '15', '10', 'Test', 's', '2', '08', '22', '0800', '', '', '', '1'); SELECT LAST_INSERT_ID();
```

Описание некоторых полей б\д:

1 - имя кампании (бд\тн autodialer.Test)

2 - число повторов набора номера (бд\тн autodialer.retry)

3 - пауза между повторами (бд\тн autodialer.pause)

4 - длительность вызова (бд\тн autodialer.timeout)

5 - число одновременных вызывов (бд\тн autodialer.concurrent)

6 - используемое число строк(autodialer.str_limit)

7 - направление в диалплане (ответ exten => s...) (бд\тн autodialer.exten)

8 - контекст исходящих (бд\тн autodialer.chan_context)

9 - контекст в extension.conf для ad (бд\тн autodialer.ext_context)


Описание работы:
ad_month - месяц начала обзвона

ad_date - дата начала обзвона

ad_day - повторять каждые N дней, если указано 0 и дата еще не прошла, то обзвон произойдет один раз и больше повторяться не будет

callerid - можно указать при желании иначе при обзвоне будет задан тот номер, на который происходит вызов

str_limit - задать используемое число строк (по умолчанию 100)

answer_status - 0, пусто или NULL, не учитывать статус дозвона в autodialer.Test (где: Test - имя кампании) или 1 пропускать и не звонить, если статус ответа "ANSWER"


Настройка сервера Mysql
Для импорта телефонных номеров из файлов csv, mysql требуется привилегия FILE, т.к. используется метод LOAD DATA INFILE.
```vi /etc/my.cnf
[mysqld]
secure-file-priv = ""
```
Перезапустите Mysql сервер.

systemctl restart mariadb

Установите привилегии FILE
Подключитесь к командной строке Mysql.

mysql -p

Установите привилегии.

grant file on *.* to autodialer@localhost identified by 'autodialer';

Проверьте привилегии каталога.
```
mysql> SHOW VARIABLES LIKE "secure_file_priv";
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| secure_file_priv |       |
+------------------+-------+
1 row in set (0.00 sec)

Создание тестовой таблицы групп с номерами Test
CREATE TABLE IF NOT EXISTS autodialer.`Test` (
`id` int(11) NOT NULL AUTO_INCREMENT,
`number` varchar(32) DEFAULT NULL,
`name` varchar(512) DEFAULT NULL,
`camp` varchar(32) DEFAULT NULL,
`status` varchar(32) DEFAULT 'NOANS',
`agent` varchar(16) DEFAULT NULL,
`timestamp` varchar(32) DEFAULT NULL,
PRIMARY KEY (`id`),
UNIQUE KEY `number` (`number`,`camp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

Импорт номеров из csv файла
Когда кампания создана, импортируйте телефонные номера из файла формата csv.

Формат файлов csv:

1234

1235

1236

или, если необходимо имя:

1234,name1

1235,name2

1236,name3

Имя может быть передано как CALLERID(name) из call file и отображаться агенту, который получил вызов.
Если файл /tmp/campname.csv загружен из Windows, то используйте другой разрыв строки в праметре LINES TERMINATED BY '\r\n'
Команда импорта номеров для группы Test
```
LOAD DATA LOCAL INFILE '/tmp/campname.csv'
IGNORE INTO TABLE autodialer.`Test`
CHARACTER SET UTF8
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(`number`, `name`) set `camp` = 'Test', `status` = 'NOANS';
```

Связка autodialer с Asterisk
Если не настроено подключение, то пропишите его
```vi /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL
Driver = /usr/lib/libmyodbc5.so
Setup = /usr/lib/libodbcmyS.so
Driver64 = /usr/lib64/libmyodbc5.so
Setup64 = /usr/lib64/libodbcmyS.so
FileUsage = 1
```
Создадим коннектор
```vi /etc/odbc.ini
[MySQL-autodialer]
Description         = MySQL connection to db autodialer
Driver              = MySQL
Servername          = localhost
Port                = 3306
Database            = autodialer
Username            = autodialer
Password            = autodialer
Charset             = utf8

vi /etc/asterisk/func_odbc.conf
;;; Autodialer
[GROUP]
prefix=AD
dsn=autodialer
readsql=select campname from campaign where id='${ARG1}'
writesql=UPDATE campaign SET ad_month='${ARG2}',ad_date='${ARG3}',ad_time='${ARG4}',ad_day='${ARG5}' WHERE campname='${ARG1}';

vi /etc/asterisk/res_odbc.conf
[autodialer]
enabled         => yes
dsn             => MySQL-autodialer
username        => autodialer
password        => autodialer
pre-connect     => yes
max_connections => 100
```

Настройка диалплана

vi /etc/asterisk/extensions_custom.conf

Тут лучше настроить, чтобы для autodialer подгружался дополнительный конфиг, но это не принципиально
```
; В начале файла подключим новый конфиг
#include "extensions_autodialer.conf"

[globals]
CallerID=8122151656

;;; Исходящие вызовы
[outcalling]
; Например для группы Test2 можно добавить сообщение из контекста include => Test2
include => Test

; Также можно создать отдельный контекст со своим сообщение для каждой группы, например Test2
; Аудио записи в custom/ создаются через IVR меню с номером *999
[Test]
exten => s,1,NoOp(Звонок с ${CHANNEL:6:-22})
 same => n,Wait(1)
 same => n,Playback(custom/Test)
 same => n,Hangup()

;;; IVR меню настройки прозвона
exten => *999,1,NoOp(Входящий c ${CHANNEL(peername)})
 same => n,Answer()
 same => n,Goto(autodialer,s,1)
 same => n,Hangup

exten => _XXX,1,NoOp(Внутренний вызов)
 same => n,SET(NUM_TO_CHECK=${EXTEN})
 same => n,Gosub(check_blf_redirect,s,1)
 same => n,AGI(/etc/asterisk/scripts/agi_set_name.sh, ${CALLERID(name)})
 same => n,Set(CALLERID(name)=${cid_name})
 same => n,Set(CALLER-ID=${CALLERID(num)})
 same => n,Set(DIR=IN)
 same => n,Set(EXT=${EXTEN})
 same => n,Gosub(call_record,s,1(${EXTEN}))
 same => n,Dial(SIP/${EXTEN})

;; Звонки в город
[DLPN_city]
exten => _XXXXXXX,1,NoOp(Звонок в город ${CALLERID(num)} -> ${EXTEN:0})
 same => n,Set(CALLER-ID=${CALLERID(num)})
 same => n,Set(Cid=${LEN(${CALLERID(num)})})
 same => n,Set(CALLERID(num)=${IF($[${Cid}<7]?${CallerID}:${CALLERID(num)})})
 same => n,Set(DIR=OUT)
 same => n,Set(EXT=${EXTEN})
 same => n,Gosub(call_record,s,1(${EXTEN}))
 same => n,Dial(SIP/trunk_out/0${EXTEN})

;; Звонки на мобильные
[DLPN_mobile]
exten => _89XXXXXXXXX,1,NoOp(Мобильный вызов ${CALLERID(num)} -> ${EXTEN:0})
 same => n,Set(CALLER-ID=${CALLERID(num)})
 same => n,Set(Cid=${LEN(${CALLERID(num)})})
 same => n,Set(CALLERID(num)=${IF($[${Cid}<7]?${CallerID}:${CALLERID(num)})})
 same => n,Set(DIR=OUT)
 same => n,Set(EXT=${EXTEN})
 same => n,Gosub(call_record,s,1(${EXTEN}))

 same => n,Dial(SIP/trunk_out/0${EXTEN})

;;; Обработка после завершения вызова
;exten => h,1,ExecIF($[ "${dnumber}" != "" ]?set(ODBC_ANSWER(1,2,3,4)=${dnumber},${campaign},${DIALSTATUS},${time}))
exten => h,1,ExecIF($[ "${dnumber}" != "" ]?set(ODBC_ANSWER(1,2,3,4)=${dnumber},${campaign},${DIALSTATUS},${STRFTIME(${EPOCH},,%d/%m/%Y-%H:%M.%S)}))
```

*Где:
Обработка после завершения вызова - добавить время ответа или сброса вызова для каждого номера в таблицу autodialer.Test (где: Test - имя кампании)

Внесем изменения для "Обработки после завершения вызова"
```vi /etc/asterisk/func_odbc.conf
[ANSWER]
dsn=autodialer
writesql=UPDATE ${VAL2} SET status='${VAL3}', timestamp='${VAL4}' WHERE camp='${VAL2}' and number='${VAL1}'
```
Применим изменения

asterisk -rx "reload"

Конфиг для autodialer

vi /etc/asterisk/extensions_autodialer.conf

; ПРИМЕЧАНИЕ: Для теста, в меню используется синтезатор речи Festival, вы можете записать качественное аудио и заменить строки со ссылками на ваши аудиофайлы
```
[autodialer]
exten => s,1,NoOp(Настройка Авто-прозвона)
 same => n,Answer()
 same => n,Festival('-. Нажмите -. 1 -. чтобы -. выполнить -. прозвон -. один раз -. 2 -. настроить -. регулярный --. прозвон -. или -. 3 -. за-писать -. сообщение ')
 same => n,Playback(beep)
 same => n,WaitExten(7)
 exten => 1,1,Goto(once_ad,1)
 exten => 2,1,Goto(reg_ad,1)
 exten => 3,1,Goto(sound_ad,1)
 exten => i,1,Playback(pbx-invalid)
 exten => i,n,Goto(autodialer,s,1)
 exten => t,1,Goto(autodialer,s,1)

exten => once_ad,1,NoOp(Выбран прозвон один раз)
 same => n,Festival('После -. сигнала -. введите -. номер -. группы -. и -. нажмите -. решётку ')
 same => n,Read(ID_GROUP,beep)
 same => n,Set(ID_GROUP=${FILTER(0-9,${ID_GROUP})})
 same => n,Set(NAME_GROUP=${AD_GROUP(${ID_GROUP})})
 same => n,GotoIf($[${ODBCROWS}<=0]?invalid_queue,1)
 same => n,Festival('-. Прозвон -. запущен ')
 same => n,System(/etc/asterisk/scripts/autodialer.sh ${NAME_GROUP})
 same => n,Hangup()

exten => reg_ad,1,NoOp(Настройка регулярного прозвона)
 same => n,Festival('После -. сигнала -. введите -. номер -. группы -. и -. нажмите -. решётку ')
 same => n,Read(ID_GROUP,beep)
 same => n,Set(ID_GROUP=${FILTER(0-9,${ID_GROUP})})
 same => n,Set(NAME_GROUP=${AD_GROUP(${ID_GROUP})})
 same => n,GotoIf($[${ODBCROWS}<=0]?invalid_queue,1)
 same => n,Goto(ad_month,1)

exten => ad_month,1,Festival('-. После -. сигнала -. введите -. цифру -. месяца для на-ча-ла -. прозвона -. нажмите -. решётку ')
 same => n,Read(AD_MONTH,beep)
 same => n,Set(AD_MONTH=${FILTER(0-9,${AD_MONTH})})
 same => n,GotoIf($[${LEN(${AD_MONTH})}>2]?ad_month,1)
 same => n,GotoIf($[${AD_MONTH}<=0]?ad_month,1)
 same => n,GotoIf($[${AD_MONTH}>12]?ad_month,1:ad_date,1)

exten => ad_date,1,Festival('После -. сигнала -. введите -. число -. месяца -. для -. нача-ла -. прозвона -. нажмите -. решётку ')
 same => n,Read(AD_DATE,beep)
 same => n,Set(AD_DATE=${FILTER(0-9,${AD_DATE})})
 same => n,GotoIf($[${LEN(${AD_DATE})}>2]?ad_date,1)
 same => n,GotoIf($[${LEN(${AD_DATE})}<=0]?ad_date,1)
 same => n,GotoIf($[${AD_DATE}>31]?ad_date,1:ad_time,1)

exten => ad_time,1,Festival('После -. сигнала -. введите -. время -. нача-ла -. прозвона -. в -. формате -. 0 -. часов -. 0 -. минут -. без -. разделителей -. нажмите -. решётку ')
 same => n,Read(AD_TIME,beep)
 same => n,Set(AD_TIME=${FILTER(0-9,${AD_TIME})})
 same => n,GotoIf($[${LEN(${AD_TIME})}>4]?ad_time,1)
 same => n,GotoIf($[${LEN(${AD_TIME})}<4]?ad_time,1)
 same => n,GotoIf($[${AD_TIME:0:2}>23]?ad_time,1)
 same => n,GotoIf($[${AD_TIME:-2}>59]?ad_time,1)

 same => n,Festival('После -. сигнала -. введите -. количество -. дней -. до следующего -. прозвона -. или -. введите -. 0 -. если -. повторы -. не -. требуются -. нажмите -. решётку ')
 same => n,Read(AD_DAY,beep)
 same => n,Set(AD_DAY=${FILTER(0-9,${AD_DAY})})
 same => n,Set(AD_GROUP(${NAME_GROUP},${AD_MONTH},${AD_DATE},${AD_TIME},${AD_DAY})='')
 same => n,Festival('-. Настройка -. завершена ')
 same => n,Hangup()

exten => sound_ad,1,NoOp(Запись сообщения для прозвона)
 same => n,Festival('После -. сигнала -. введите -. номер -. группы -. нажмите -. решётку ')
 same => n,Read(ID_GROUP,beep)
 same => n,Set(ID_GROUP=${FILTER(0-9,${ID_GROUP})})
 same => n,Set(NAME_GROUP=${AD_GROUP(${ID_GROUP})})
 same => n,GotoIf($[${ODBCROWS}<=0]?invalid_queue,1)
 same => n,Festival('-. Говорите -. после -. сигнала -. для -. завершения -. записи -. нажмите -. решетку -. после -. этого -. вы -. сможете -. прослушать -. запись ')
 same => n,Playback(beep)
 same => n,Record(custom/${NAME_GROUP}:gsm)
 same => n,Festival('-. Запись -. завершена ')
 same => n,Wait(1)
 same => n,Playback(custom/${NAME_GROUP})
 same => n,Hangup()
```

Сценарии создания Call файлов
1) Скрипт управления запуском прозвона по времени
Скрипт autodialer.sh обращается в б\д и выбирает нужные значения, проверяя их на ошибки, также задает переменные дат прозвона и создает Call файлы
Скрипт нужно добавить в cron для запуска каждую минуту
crontab -e
*/1 * * * * /etc/asterisk/scripts/autodialer.sh -t

Обратите внимание на параметр limit в скрипте, он задает ограничение строк номеров при чтении из б\д
В данной строчке скрипта можно задать callerid по умолчанию если в б\д не задано значение
```[ "${callerid}" = "NULL" -o "${callerid}" = "" -o "${callerid}" = "0" ] && callerid="8812"
```
Скрипт можно запускать вручную с параметрами запуска
Обычный запуск, прозвон по всем кампаниям

./autodialer.sh -a


Запуск прозвона для компании CampTest

./autodialer.sh CampTest

Запуск создания Call файлов на определенное время\дату для компании CampTest

./autodialer.sh CampTest -t

Запуск создания Call файлов на определенную дату для всех кампаний

./autodialer.sh -t





*Дополнительно
Автоответы для громкого оповещения
Принцип работы: Звоним на номер автообзвона *999, записываем голосовое сообщение и выбираем запуск автообзвона, для разных телефонов существуют разные опции автоответа - это настраивается на конкретном телефонном аппарате, после чего при звонке на данный телефон, через asterisk ему (для данного телефона) необходимо передать опцию автоответа по громкой связи (опции для каждого телефона разные), ниже приведен список опций для разных моделей, проверяется перебором, какая опция подходит.
Опции:

SIPAddHeader(Alert-Info: Ring Answer) ; AudioCodes 420HD и GrandStream GXP-1625

SIPAddHeader(Alert-Info: Info=Alert-Autoanswer)

SIPAddHeader(Call-Info:\;Answer-After=0)

SIPAddHeader(P-Auto-Answer: normal)

SIPAddHeader(Answer-Mode: Auto) ; Avaya 9608-9611G

Источник информации: http://blog.koobik.net/asterisk-emergency-notification-system/

Для AudioCodes 420HD это делается через меню Management — Manual Update — Configuration file. Нужно найти параметр voip/auto_answer/enabled и установить ему значение 1.
Для GrandStream GXP-1625 настройка немного проще: Accounts — Account X — Call Settings — Allow Auto Answer by Call-Info «YES».

В примере я использовал Avaya 9608G, на ней нужно прописать опцию (возможно её можно настроить и на самом т\а) в конфиге на HTTP сервере, который использует телефон Avaya/SIP 46xxsettings.txt, добавить опцию
SET HEADSYS 0

Далее добавить в диалплан опцию для телефона

vi /etc/asterisk/extensions_custom.conf
```
exten => _XXX,1,NoOp(Внутренний вызов с ${CALLERID(num)} -> на номер ${EXTEN})
 same => n,SET(NUM_TO_CHECK=${EXTEN})
 same => n,Gosub(check_blf_redirect,s,1)
 same => n,AGI(/etc/asterisk/scripts/agi_set_name.sh.x, ${CALLERID(name)})
 same => n,Set(CALLERID(name)=${cid_name})
 same => n,Set(CALLER-ID=${CALLERID(num)})
 same => n,Set(DIR=IN)
 same => n,Set(EXT=${EXTEN})
 same => n,Gosub(call_record,s,1(${EXTEN}))
 same => n,ExecIF($[ "${CALLERID(name)}" == "Answer-Mode: Auto" ]?SIPAddHeader(Answer-Mode: Auto)); Avaya 9608G
 same => n,Dial(SIP/${EXT})
 same => n,Goto(s-${DIALSTATUS},1)
 ```

Далее, для того чтобы опция (same => n,ExecIF($[ "${CALLERID(name)}" == "Answer-Mode: Auto" ]?SIPAddHeader(Answer-Mode: Auto)); Avaya 9608G) отработала её еще нужно внести в б\д, в нужной компании в поле fullname, в принципе вы можете задать там любое значение , например, имя кампании или имя телефонов avaya, только поменяйте тогда условие в диалплане на нужное!

Источник вдохновения

https://asterisk-pbx.ru/wiki/soft/call_center/asterisk_autodialer


В РАЗРАБОТКЕ:

1) Добавить возморжность прозвона по часам, через нескольео часов, интервал обзвона (складывать минуты и часы)

2) Добавить статусы ответов с отправкой на email в случае, если абонент не ответил (установка postfix)

3) Частичная установка ПО автопрозвона скриптом autodialer.sh (autodialer.sh -I)

4) Добавление групп и импорт номеров в б\д скриптом autodialer.sh (autodialer.sh -igr Test и autodialer.sh -ixml Test /tmp/campname.csv)
