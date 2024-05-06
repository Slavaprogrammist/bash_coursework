#!/bin/bash

lock_file="ZRDN1/zrdn1.lock"

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
destroy_directory="/tmp/GenTargets/Destroy" # Уничтоженные цели.
file_path="ZRDN1/detected_Zrdn1.txt" # Обнаруженные цели ЗРДН.
file2_path="ZRDN1/confrimed_balistic_Zrdn1.txt" # Подтвержденные цели ЗРДН.
file3_path="ZRDN1/shot_Zrdn1.txt" # Цели, по которым произведен выстрел.
messages_path="messages/information" # Информационные сообщения ЗРДН.
time_format="%d_%m_%Y_%H-%M-%S.%3N"
source Koordinates.sh
source Is_in.sh

password="1234"

time=$(TZ=Europe/Moscow date +"$time_format")
echo "$time,Zrdn1,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"

if [ -d "$directory" ]; then # Является ли путь директорией
    echo -n > "$file_path"
    echo -n > "$file2_path"
    echo -n > "$file3_path"
    filenames=() # Массив для хранения имен файлов с данными о целях.
    rocket=20
    while true; do
        filenames=($(ls -t "$directory" | head -n 30 2>/dev/null)) # Получение списка файлов с координатами целей.
        for name in "${filenames[@]}"; do
            id=$(ls -t "$directory/$name" | tail -c 7 2>/dev/null) # Идентификатор цели из имени файла.
            IFS=, read -r x y < /tmp/GenTargets/Targets/$name 2>/dev/null # Координаты цели из файла с указанным именем.
            x="${x#X}" # Удаление префиксов
            y="${y#Y}"
            circle=$(target_in_circle $x $y $ZRDN1_x $ZRDN1_y $ZRDN1_RADIUS) # Находится ли цель в пределах области действия ЗРДН.
            if [ "$circle" -eq 1 ]; then # Цель находится в пределах области действия ЗРДН.
                if ! grep -q "^$id " "$file2_path"; then # Если цель записана в файле confrimed_balistic_Zrdn1, то мы её игнорируем.
                    if grep -q "^$id " "$file3_path"; then # Был сделан выстрел, но цель не была уничтожена.
                        time=$(TZ=Europe/Moscow date +"$time_format")
                        echo "$time, Target $id don't destroyed" # Сообщение о том, что цель не была уничтожена.
                        echo "$time,Zrdn1,no kill,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                        sed -i "/^$id/d" "$file3_path" # Удаляется запись об этой цели, чтобы избежать повторного вывода сообщения.
                    fi
                    # Если цель уже встретилась один раз и записана в detected_targets, то считаем её скорость.
                    # Если это самолёт или ракета, то сбиваем
                    if ! grep -q "^$id " "$file3_path"; then # В цель не выстрелили.
                        if ! grep -q "^($id " "$file3_path"; then
                            if grep -q "^$id " "$file_path"; then # Цель была обнаружена и ее координаты записаны в файл.
                                read -r _ last_x last_y <<< "$(grep "^$id " "$file_path" | tail -n 1)"
                                if [[ $x!=$last_x && $y!=$last_y ]]; then # Проверка движения цели.
                                    speed_info=$(calculate_speed $x $y $last_x $last_y) # Считаем скорость
                                fi
                                if [[ -n $speed_info && $speed_info != 0 ]]; then # Есть ли скорость, неравная нулю.
                                    type=$(check_speed $speed_info) # Определение типа цели на основе ее скорости.
                                    time=$(TZ=Europe/Moscow date +"$time_format")  
                                    echo "$time, Confirm target id $id X $x Y $y speed $speed_info type $type"
                                    echo "$time,Zrdn1,confirm,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                    if [[ $rocket -gt 0 && ($type == "rocket" || $type == "plane") ]]; then # Есть ракеты и цель является ракетой или самолетом.
                                        touch "/tmp/GenTargets/Destroy/$id" # Создание файла, указывающего, что цель была уничтожена.
                                        echo "(($id $speed_info" >> "$file3_path" # Добавление записи о цели в файл.
                                        rocket=$(( rocket - 1 ))
                                        sed -i "/^$id/d" "$file_path" # Удаление информации о цели из файла, содержащего обнаруженные цели.
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Shot target $id, speed $speed_info, type $type" # Вывод сообщения о том, что цель была сбита.
                                        echo "$time,Zrdn1,shot,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                        echo "$time,Zrdn1,ammo left,$rocket" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/-$time.log"
                                    elif [[ $type == "ballistic" ]]; then
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    elif [[ $rocket -le -1 && ($type == "rocket" || $type == "plane") ]]; then
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    else
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    fi
                                    if [[ $rocket == 0 ]]; then
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Ammo ran out" # Сообщение о том, что ракеты закончились.
                                        echo "$time,Zrdn1,no ammo" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                        rocket=$(( rocket - 1 ))
                                    fi
                                    speed_info=0
                                fi
                            else
                                echo "$id $x $y" >> "$file_path" # Если цель встречается впервые, записываем её id и координаты.
                            fi
                        fi
                    fi
                fi
            fi
        done
        while IFS= read -r line; do
            time=$(TZ=Europe/Moscow date +"$time_format")
            echo "$time, Target $line destroyed" # Сообщение о разрушении цели. 
            echo "$time,Zrdn1,destroyed,$line" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
        done < <(grep -E '^[^(]' "$file3_path")
        sed -i '/^[^(]/d' $file3_path # Удаление строк из file3_path, которые не начинаются с символа (.
        sed -i '/^(/ s/^(//' $file3_path # Удаление символов ( из начала строк, которые начинаются с (.
        if [ -f "ZRDN1/hello.log" ]; then
            decrypted_content=$(openssl aes-256-cbc -pbkdf2 -a -d -salt -pass "pass:$password" -in "ZRDN1/hello.log")
            if [ "$decrypted_content" = "hello" ]; then
                time=$(TZ=Europe/Moscow date +"$time_format")
                echo "$time,Zrdn1,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"
            fi
            rm "ZRDN1/hello.log"
        fi
        sleep 0.3
    done
else
    echo "Dnf"
fi
