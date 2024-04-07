#!/bin/bash

lock_file="kp_vko.lock"

if [ -e "$lock_file" ]; then
    echo "Script already work"
    exit 1
fi

touch "$lock_file"

program_end() {
    rm -f "$lock_file"
    exit
}
trap program_end EXIT SIGINT

rm -f db/system.db || true
sqlite3 db/system.db "DROP TABLE IF EXISTS Work_Journal;"
sqlite3 db/system.db << CREATE_Work_Journal
CREATE TABLE Work_Journal (
 id INTEGER PRIMARY KEY,
 time DATETIME NOT NULL,
 object_name TEXT NOT NULL,
 information TEXT NOT NULL,
 target_id varchar(6),
 coordinates TEXT,
 speed TEXT,
 type TEXT
);
CREATE_Work_Journal




messages="messages/information"
inputs="messages/alive"
password="metelev"
log_journal="log/system_journal.log"
counter=0
counter_input=0
key=0
array=(0 0 0 0 0 0 0)
confirm_array=(0 0 0 0 0 0 0)
name=""
time_format="%d_%m_%Y_%H-%M-%S.%3N"
while true; do
	for file in $(ls -tr "$messages" 2>/dev/null); do
		IFS=',' read -r -a content < <(openssl aes-256-cbc -pbkdf2 -d -a -pass pass:"$password" -in "$messages/$file")
		sqlite3 db/system.db "insert into Work_Journal (time, object_name, target_id, information, coordinates, speed, type)
			values ('${content[0]}','${content[1]}','${content[2]}','${content[3]}','${content[4]}','${content[5]}','${content[6]}');"
		echo "${content[0]} ${content[1]} ${content[2]} ${content[3]} ${content[4]} ${content[5]} ${content[6]}"
		echo "${content[0]} ${content[1]} ${content[2]} ${content[3]} ${content[4]} ${content[5]} ${content[6]}" >> $log_journal
		rm -f "$messages/$file"
	done
	sleep 1


	#проверка работоспособности каждой из станций
	for file in $(ls -tr "$inputs" 2>/dev/null); do
		IFS=',' read -r -a alive < <(openssl aes-256-cbc -pbkdf2 -d -a -pass pass:"$password" -in "$inputs/$file")
		object_name="${alive[1]}"
		index=0

		case $object_name in
		    "Zrdn1") index=0 ;;
		    "Zrdn2") index=1 ;;
		    "Zrdn3") index=2 ;;
		    "Spro")  index=3 ;;
		    "Rls1")  index=4 ;;
		    "Rls2")  index=5 ;;
		    "Rls3")  index=6 ;;
		esac

		confirm_array[$index]=1
		if [ "${array[$index]}" = 0 ]; then
		    array[$index]=1
		    sqlite3 db/system.db "insert into Work_Journal (time, object_name, target_id, information, coordinates, speed, type)
		        values ('${alive[0]}','$object_name','${alive[2]}','${alive[3]}','${alive[4]}','${alive[5]}','${alive[6]}');"
		    echo "${alive[0]} $object_name ${alive[2]} ${alive[3]} ${alive[4]} ${alive[5]} ${alive[6]}"
		    echo "${alive[0]} $object_name ${alive[2]} ${alive[3]} ${alive[4]} ${alive[5]} ${alive[6]}" >> $log_journal
		fi
		rm "$inputs/$file"
	done
						      
	#проверяем, все ли станции функционируют
	if ((key == 1)); then
		counter_input=$((counter_input + 1))
		if ((counter_input == 2)); then
			counter_input=0
			key=0
			for ((i=0; i<7; i++)); do
			    if [[ ${confirm_array[$i]} -eq 0 && ${array[$i]} -eq 1 ]]; then
			        case $i in
			            0) not_work="Zrdn1" ;;
			            1) not_work="Zrdn2" ;;
			            2) not_work="Zrdn3" ;;
			            3) not_work="Spro" ;;
			            4) not_work="Rls1" ;;
			            5) not_work="Rls2" ;;
			            6) not_work="Rls3" ;;
			        esac
			        array[$i]=0
			        time=$(TZ=Europe/Moscow date +"$time_format")
			        sqlite3 db/system.db "insert into Work_Journal (time, object_name, target_id, information, coordinates, speed, type)
						values ('$time','$not_work','no signal','','','','');"
					echo "$time $not_work no signal"
					echo "$time $not_work no signal" >> $log_journal
			    fi
			done
			confirm_array=(0 0 0 0 0 0 0)
		fi
	fi
	counter=$((counter + 1))

	#каждые 30 итераций проверяем, все ли станции живы и функционируют
	if ((counter > 30)); then
		counter=0
		key=1
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "RLS1/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "RLS2/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "RLS3/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "SPRO/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "ZRDN1/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "ZRDN2/hello.log"
		echo "hello" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "ZRDN3/hello.log"
	fi
done
