#!/bin/bash

lock_file="SPRO/spro.lock"

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
directory="/tmp/GenTargets/Targets"
destroy_directory="/tmp/GenTargets/Destroy"
file_path="SPRO/detected_spro.txt"
file2_path="SPRO/confrimed_rockets_planes.txt"
file3_path="SPRO/shot_spro.txt"
messages_path="messages/information"
time_format="%d_%m_%Y_%H-%M-%S.%3N"
source Koordinates.sh
source Is_in.sh

password="metelev"

time=$(TZ=Europe/Moscow date +"$time_format")
echo "$time,Spro,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"

if [ -d "$directory" ]; then
    echo -n > "$file_path"
    echo -n > "$file2_path"
    echo -n > "$file3_path"
    # Для очистки файлов с записями считаем итерации
    # iteration=0
    filenames=()
    rocket=10
    while true; do
        filenames=($(ls -t "$directory" | head -n 30 2>/dev/null))
        for name in "${filenames[@]}"; do
            id=$(ls -t "$directory/$name" | tail -c 7 2>/dev/null)
            IFS=, read -r x y < /tmp/GenTargets/Targets/$name 2>/dev/null
            x="${x#X}"
            y="${y#Y}"
            circle=$(target_in_circle $x $y $SPRO_x $SPRO_y $SPRO_RADIUS)
            if [ "$circle" -eq 1 ]; then
                # Если цель записана в файле confrimed_rockets_planes, то мы её игнорируем
                if ! grep -q "^$id " "$file2_path"; then
                    if grep -q "^$id " "$file3_path"; then
                        time=$(TZ=Europe/Moscow date +"$time_format")
                        echo "$time, Target $id don't destroyed"
                        echo "$time,Spro,no kill,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                        sed -i "/^$id/d" "$file3_path"
                    fi
                    # Если цель уже встретилась один раз и записана в detected_targets то считаем её скорость
                    # и если это самолёт или ракета, то пробуем сбить
                    if ! grep -q "^$id " "$file3_path"; then
                        if ! grep -q "^($id " "$file3_path"; then
                            if grep -q "^$id " "$file_path"; then
                                read -r _ last_x last_y <<< "$(grep "^$id " "$file_path" | tail -n 1)"
                                if [[ $x!=$last_x && $y!=$last_y ]]; then
                                speed_info=$(calculate_speed $x $y $last_x $last_y)
                                fi  
                                if [[ -n $speed_info && $speed_info != 0 ]]; then
                                    type=$(check_speed $speed_info)
                                    time=$(TZ=Europe/Moscow date +"$time_format")
                                    echo "$time, Confirm target id $id X $x Y $y speed $speed_info type $type"
                                    echo "$time,Spro,confirm,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                    if [[ $rocket -gt 0 && $type == "ballistic" ]]; then
                                        touch "/tmp/GenTargets/Destroy/$id"
                                        echo "(($id $speed_info" >> "$file3_path"
                                        rocket=$(( rocket - 1 ))
                                        sed -i "/^$id/d" "$file_path"
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Shot target $id, speed $speed_info, type $type"
                                        echo "$time,Spro,shot,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                        echo "$time,Spro,ammo left,$rocket" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/-$time.log"
                                    elif [[ $type == "rocket" || $type == "plane" ]]; then
                                        echo "$id $speed_info" >> "$file2_path"
                                    elif [[ $rocket -le -1 && $type == "ballistic" ]]; then
                                        echo "$id $speed_info" >> "$file2_path"
                                    else
                                        echo "$id $speed_info" >> "$file2_path"
                                    fi
                                    if [[ $rocket == 0 ]]; then
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Ammo ran out"
                                        echo "$time,Spro,no ammo" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                        rocket=$(( rocket - 1 ))
                                    fi
                                    speed_info=0
                                fi
                            else
                                # Если цель встречается впервые, записываем её id и координаты
                                echo "$id $x $y" >> "$file_path"
                                #time=$(TZ=Europe/Moscow date +"$time_format")
                                #echo "$time, Detect target id $id X $x Y $y"
                                #echo "$time,Spro,detect,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/Spro-$id-detect-$time.log"
                            fi
                        fi
                    fi
                fi
            fi
        done
        while IFS= read -r line; do
            time=$(TZ=Europe/Moscow date +"$time_format")
            echo "$time, Target $line destroyed"
            echo "$time,Spro,destroyed,$line" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
        done < <(grep -E '^[^(]' "$file3_path")
        sed -i '/^[^(]/d' $file3_path
        sed -i '/^(/ s/^(//' $file3_path
        if [ -f "SPRO/hello.log" ]; then
            decrypted_content=$(openssl aes-256-cbc -pbkdf2 -a -d -salt -pass "pass:$password" -in "SPRO/hello.log")
            if [ "$decrypted_content" = "hello" ]; then
                time=$(TZ=Europe/Moscow date +"$time_format")
                echo "$time,Spro,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"
            fi
            rm "SPRO/hello.log"
        fi
        sleep 0.3
        #sleep 0.6
    done
else
    echo "Dnf"
fi
