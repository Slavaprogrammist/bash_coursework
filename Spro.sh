#!/bin/bash

lock_file="SPRO/spro.lock" #путь к файлу блокировки

# Проверка существование файла блокировки, Оператор -e проверяет, существует ли файл с указанным путем. Если файл существует, 
# значит скрипт уже запущен, и в этом случае выводится сообщение "Script already work", и скрипт завершает работу.
if [ -e "$lock_file" ]; then
    echo "Script already work"
    exit 1
fi

# Если файл блокировки не существует, то скрипт создает его с помощью команды touch, которая создает пустой файл, если он не существует, 
# или обновляет временные метки доступа к файлу, если он существует.
touch "$lock_file"

# Удаление файла блокировки и завершение работы скрипта.
program_end() {
    rm -f "$lock_file" # флаг -f игнорирует ошибки, если файл уже не существует.
    exit
}
trap program_end EXIT SIGINT

directory="/tmp/GenTargets/Targets"
destroy_directory="/tmp/GenTargets/Destroy" # Уничтоженные цели.
file_path="SPRO/detected_spro.txt" # Обнаруженные цели СПРО.
file2_path="SPRO/confrimed_rockets_planes.txt" # Подтвержденные цели СПРО.
file3_path="SPRO/shot_spro.txt" # Цели, по которым произведен выстрел.
messages_path="messages/information" # Информационные сообщения СПРО.
time_format="%d_%m_%Y_%H-%M-%S.%3N"
source Koordinates.sh
source Is_in.sh

password="1234"

# Создание сообщения о работоспособности РЛС, шифрование его с использованием заданного пароля
# и запись зашифрованного сообщения в файл с уникальным именем в директорию.
time=$(TZ=Europe/Moscow date +"$time_format")
echo "$time,Spro,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"

if [ -d "$directory" ]; then # Является ли путь директорией
    echo -n > "$file_path" # Вывод пустой строки без символа перевода строки.
    echo -n > "$file2_path" # Затем этот вывод перенаправляется в файлы $file_path, $file2_path и $file3_path, 
    echo -n > "$file3_path" # чтобы очистить их содержимое.
    filenames=() # Массив для хранения имен файлов с данными о целях.
    rocket=10
    while true; do
        filenames=($(ls -t "$directory" | head -n 30 2>/dev/null)) # Получение списка файлов с координатами целей.
        for name in "${filenames[@]}"; do
            id=$(ls -t "$directory/$name" | tail -c 7 2>/dev/null) # Идентификатор цели из имени файла.
            IFS=, read -r x y < /tmp/GenTargets/Targets/$name 2>/dev/null # Координаты цели из файла с указанным именем.
            x="${x#X}" # Удаление префиксов
            y="${y#Y}" # Удаление префиксов
            circle=$(target_in_circle $x $y $SPRO_x $SPRO_y $SPRO_RADIUS) # Находится ли цель в пределах области действия СПРО.
            if [ "$circle" -eq 1 ]; then # Цель находится в пределах области действия СПРО.
                if ! grep -q "^$id " "$file2_path"; then # Если цель записана в файле confrimed_rockets_planes, то мы её игнорируем.
                    if grep -q "^$id " "$file3_path"; then # Был сделан выстрел, но цель не была уничтожена.
                        time=$(TZ=Europe/Moscow date +"$time_format")
                        echo "$time, Target $id don't destroyed" # Сообщение о том, что цель не была уничтожена.
                        echo "$time,Spro,no kill,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
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
                                    echo "$time,Spro,confirm,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                    if [[ $rocket -gt 0 && $type == "ballistic" ]]; then # Проверка условия наличия ракет и тип цели является баллистическим.
                                        touch "/tmp/GenTargets/Destroy/$id" # Создание файла, указывающего, что цель была выбрана для уничтожения.
                                        echo "(($id $speed_info" >> "$file3_path" # Добавление записи о цели в файл.
                                        rocket=$(( rocket - 1 ))
                                        sed -i "/^$id/d" "$file_path" # Удаление информации о цели из файла, содержащего обнаруженные цели.
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Shot target $id, speed $speed_info, type $type" # Вывод сообщения о том, что цель была сбита.
                                        echo "$time,Spro,shot,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                                        echo "$time,Spro,ammo left,$rocket" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/-$time.log"
                                    elif [[ $type == "rocket" || $type == "plane" ]]; then
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    elif [[ $rocket -le -1 && $type == "ballistic" ]]; then
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    else
                                        echo "$id $speed_info" >> "$file2_path" # Добавление информации о цели в file2_path.
                                    fi
                                    if [[ $rocket == 0 ]]; then
                                        time=$(TZ=Europe/Moscow date +"$time_format")
                                        echo "$time, Ammo ran out" # Сообщение о том, что ракеты закончились.
                                        echo "$time,Spro,no ammo" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
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
            echo "$time,Spro,destroyed,$line" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
        done < <(grep -E '^[^(]' "$file3_path")
        sed -i '/^[^(]/d' $file3_path # Удаление строк из file3_path, которые не начинаются с символа (.
        sed -i '/^(/ s/^(//' $file3_path # Удаление символов ( из начала строк, которые начинаются с (.
        if [ -f "SPRO/hello.log" ]; then
            decrypted_content=$(openssl aes-256-cbc -pbkdf2 -a -d -salt -pass "pass:$password" -in "SPRO/hello.log")
            if [ "$decrypted_content" = "hello" ]; then
                time=$(TZ=Europe/Moscow date +"$time_format")
                echo "$time,Spro,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"
            fi
            rm "SPRO/hello.log"
        fi
        sleep 0.3
    done
else
    echo "Dnf"
fi
