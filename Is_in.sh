#!/bin/bash

target_in_circle() { # Аргументы: (x,y) - координаты цели, (cx,cy) - координаты центра окружности, r - радиус обнаружения
 local x=$1
 local y=$2
 local cx=$3
 local cy=$4
 local r=$5

 local distance=$(echo "sqrt((${x}-${cx})^2 + (${y}-${cy})^2)" | bc -l)

 if (($(echo "$distance <= $r" | bc -l) )); then
  result="1"
 else
  result="0"
 fi

 echo $result
}

distance() {
   local x=$1
   local y=$2
   local cx=$3
   local cy=$4
   local distance=$(echo "sqrt((${x}-${cx})^2 + (${y}-${cy})^2)" | bc -l)
   echo $distance
}

target_in_sector() {
 # Аргументы: (x,y) - координаты цели, (cx,cy) - координаты центра окружности, r - радиус обнаружения, 
 # alpha - начальный угол, beta - конечный угол.
 # Смотрим пространство между углами alpha и beta
    local x=$1
    local y=$2
    local cx=$3
    local cy=$4
    local r=$5
    local alpha=$6
    local beta=$7

    local theta=$(echo "a( (${y}-${cy}) / (${x}-${cx}) ) * 180 / 3.141592653589793238462643" | bc -l)

    if (( $(echo "$x < $cx" | bc -l) )); then
      theta=$(echo "$theta + 180" | bc -l)
    fi

    if (( $(echo "$x > $cx && $y < $cy " | bc -l) )); then
        theta=$(echo "$theta + 360" | bc -l)
    fi

    local incircle=$(target_in_circle $x $y $cx $cy $r)
    local res=0
    if [ "$incircle" -eq 1 ] && (( $(echo "$theta >= $alpha && $theta <= $beta" | bc -l) )); then
        res=1
    elif [ "$incircle" -eq 1 ] && [ "$alpha" -eq 345 ] && ((( $(echo "$theta >= $alpha && $theta < 360" | bc -l) )) || (( $(echo "0 < $theta && $theta < $beta" | bc -l) ))); then
        res=1
    fi

    echo "$res"
}

calculate_speed() {
    local x1=$1
    local y1=$2
    local x2=$3
    local y2=$4
    echo "scale=2; sqrt((${x2}-${x1})^2 + (${y2}-${y1})^2)" | bc
}

is_line_through_circle() {
    local center_x=$1
    local center_y=$2
    local radius=$3
    local x1=$4
    local y1=$5
    local x2=$6
    local y2=$7
    
    # Вычисляем коэффициенты уравнения прямой (Ax + By + C = 0).
    local A=$((y1 - y2))
    local B=$((x2 - x1))
    local C=$((x1*y2 - x2*y1))
    # Вычисляем расстояние от центра окружности до прямой.
    local distance_to_line=$(echo "(${A}*${center_x} + ${B}*${center_y} + ${C}) / sqrt(${A}^2 + ${B}^2)" | bc -l)

    # Если расстояние до прямой меньше или равно радиусу, то прямая проходит через окружность.
    if (( $(echo "${distance_to_line} <= ${radius}" | bc -l) )); then
        echo "true"
    else
        echo "false"
    fi
}

check_speed() {
   speed=$1

   if (( $(echo "$speed >= 50 && $speed <= 250" | bc -l) )); then
      echo "plane"
   elif (( $(echo "$speed > 250 && $speed <= 1000" | bc -l) )); then
      echo "rocket"
   elif (( $(echo "$speed >= 8000 && $speed <= 10000" | bc -l) )); then
      echo "ballistic"
   fi
}