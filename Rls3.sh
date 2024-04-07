#!/bin/bash

lock_file="RLS3/rls3.lock"

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
file_path="RLS3/detected_Rls3.txt"
file2_path="RLS3/confrimed_Rls3.txt"
messages_path="messages/information"
time_format="%d_%m_%Y_%H-%M-%S.%3N"
source Koordinates.sh
source Is_in.sh

password="metelev"

time=$(TZ=Europe/Moscow date +"$time_format")
echo "$time,Rls3,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"

if [ -d "$directory" ]; then
   echo -n > "$file_path"
   echo -n > "$file2_path"
   # Для очистки файлов с записями считаем итерации
   # iteration=0
   filenames=()
   while true; do
      filenames=($(ls -t "$directory" | head -n 30 2>/dev/null))
      for name in "${filenames[@]}"; do
         id=$(ls -t "$directory/$name" | tail -c 7 2>/dev/null)
         IFS=, read -r x y < /tmp/GenTargets/Targets/$name 2>/dev/null
         x="${x#X}"
         y="${y#Y}"
         sector=$(target_in_sector $x $y $RLS3_x $RLS3_y $RLS3_RADIUS $RLS3_START_ANGLE $RLS3_END_ANGLE)
         if [ "$sector" -eq 1 ]; then
            #iteration=$((iteration + 1))
            # Если цель записана в файле confrimed_targets, то мы её игнорируем
            if ! grep -q "^$id " "$file2_path"; then
               #Если цель уже встретилась один раз и записана в detected_targets то считаем её скорость и записываем в confrimed
               if grep -q "^$id " "$file_path"; then
                  read -r _ last_x last_y <<< "$(grep "^$id " "$file_path" | tail -n 1)"
                  if [[ $x!=$last_x && $y!=$last_y ]]; then
                     speed_info=$(calculate_speed $x $y $last_x $last_y)
                     to_spro=$(is_line_through_circle $SPRO_x $SPRO_y $SPRO_RADIUS $x $y $last_x $last_y)
                  fi
                  if [[ -n $speed_info && $speed_info != 0 ]]; then
                     echo "$id $speed_info" >> "$file2_path"
                     type=$(check_speed $speed_info)
                     time=$(TZ=Europe/Moscow date +"$time_format")
                     echo "$time, Confirm target id $id X $x Y $y speed $speed_info type $type"
                     echo "$time,Rls3,confirm,$id,$x $y,$speed_info,$type" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                     distance1=$(distance $x $y $SPRO_x $SPRO_y)
                     distance2=$(distance $last_x $last_y $SPRO_x $SPRO_y)
                     if [[ $to_spro == "true" && $type == "ballistic" && $(echo "${distance1} > ${distance2}" | bc -l) ]]; then
                        time=$(TZ=Europe/Moscow date +"$time_format")
                        echo "$time, Target id $id X $x Y $y goes to Spro"
                        echo "$time,Rls3,toSpro,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/$time.log"
                     fi
                     speed_info=0
                  fi
               else
                  # Если цель встречается впервые, записываем её id и координаты
                  echo "$id $x $y" >> "$file_path"
                  #time=$(TZ=Europe/Moscow date +"$time_format")
                  #echo "$time, Detect target id $id X $x Y $y"
                  #echo "$time,Rls3,detect,$id,$x $y" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "$messages_path/Rls3-$id-detect-$time.log"
               fi
            fi
         fi
      done
      if [ -f "RLS3/hello.log" ]; then
            decrypted_content=$(openssl aes-256-cbc -pbkdf2 -a -d -salt -pass "pass:$password" -in "RLS3/hello.log")
            if [ "$decrypted_content" = "hello" ]; then
               time=$(TZ=Europe/Moscow date +"$time_format")
                echo "$time,Rls3,i am alive" | openssl aes-256-cbc -pbkdf2 -a -salt -pass pass:$password > "messages/alive/$time.log"
            fi
            rm "RLS3/hello.log"
        fi
      #sleep 0.1
      #if [ $iteration -gt 100 ]; then
      #   iteration=0
      #   sed -i '1,2d' "$file_path"
      #   sed -i '1,2d' "$file2_path"
      #fi
   done
else
   echo "Dnf"
fi